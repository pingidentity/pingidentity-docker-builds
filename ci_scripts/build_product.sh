#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# This script builds the product images
#
test "${VERBOSE}" = "true" && set -x

#
# Usage printing function
#
usage() {
    test -n "${*}" && echo "${*}"
    cat << END_USAGE
Usage: ${0} {options}
    where {options} include:
    -p, --product
        The name of the product for which to build a docker image
    -s, --shim
        the name of the operating system for which to build a docker image
    -j, --jvm
        the id of the jvm to build
    -v, --version
        the version of the product for which to build a docker image
        this setting overrides the versions in the version file of the target product
    --dry-run
        does everything except actually call the docker command and prints it instead
    --fail-fast
        exit and report failure when an error occurs
    --no-cache
        no docker cache
    --snapshot
        create snapshot image
    --verbose-build
        verbose docker build not using docker buildkit
    --help
        Display general usage information
END_USAGE
    exit 99
}

# export PING_IDENTITY_SNAPSHOT=--snapshot to trigger snapshot build
DOCKER_BUILDKIT=1
noCache=${DOCKER_BUILD_CACHE}
while ! test -z "${1}"; do
    case "${1}" in
        -p | --product)
            shift
            test -z "${1}" && usage "You must provide a product to build"
            productToBuild="${1}"
            ;;
        -s | --shim)
            shift
            test -z "${1}" && usage "You must provide an OS Shim"
            shimsToBuild="${shimsToBuild:+${shimsToBuild} }${1}"
            ;;
        -j | --jvm)
            shift
            test -z "${1}" && usage "You must provide a JVM id"
            jvmsToBuild="${jvmsToBuild:+${jvmsToBuild} }${1}"
            ;;
        -v | --version)
            shift
            test -z "${1}" && usage "You must provide a version to build"
            versionsToBuild="${versionsToBuild:+${versionsToBuild} }${1}"
            ;;
        --no-cache)
            noCache="--no-cache"
            ;;
        --verbose-build)
            progress="--progress plain"
            ;;
        --dry-run)
            dryRun="echo"
            ;;
        --fail-fast)
            failFast=true
            ;;
        --snapshot)
            PING_IDENTITY_SNAPSHOT="--snapshot"
            export PING_IDENTITY_SNAPSHOT
            ;;
        --help)
            usage
            ;;
        *)
            usage "Unrecognized option"
            ;;
    esac
    shift
done

if test -z "${productToBuild}"; then
    echo "You must specify a product name to build, for example pingfederate or pingcentral"
    usage
fi

if test -z "${CI_COMMIT_REF_NAME}"; then
    CI_PROJECT_DIR="$(
        cd "$(dirname "${0}")/.." || exit 97
        pwd
    )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

# Handle snapshot pipeline logic and requirements
if test -n "${PING_IDENTITY_SNAPSHOT}"; then
    case "${productToBuild}" in
        pingaccess)
            snapshot_url="${SNAPSHOT_ARTIFACTORY_URL}"
            ;;
        pingcentral)
            snapshot_url="${SNAPSHOT_PINGCENTRAL_URL}"
            ;;
        pingfederate)
            snapshot_url="${SNAPSHOT_BLD_FED_URL}"
            ;;
        pingdelegator)
            snapshot_url="${SNAPSHOT_DELEGATOR_URL}"
            ;;
        pingauthorize | pingauthorizepap | pingdataconsole | pingdatasync | pingdirectory | pingdirectoryproxy)
            snapshot_url="${SNAPSHOT_NEXUS_URL}"
            ;;
        *)
            echo "Snapshot not supported"
            exit 0
            ;;
    esac
fi

# Handle versions to build and shims to build for snapshot images
if test -z "${versionsToBuild}"; then
    if test -n "${PING_IDENTITY_SNAPSHOT}"; then
        versionsToBuild=$(_getLatestSnapshotVersionForProduct "${productToBuild}")
        latestVersion=$(_getLatestVersionForProduct "${productToBuild}")
        if test -z "${shimsToBuild}"; then
            shimsToBuild=$(_getShimsToBuildForProductVersion "${productToBuild}" "${latestVersion}")
        fi
    else
        versionsToBuild=$(_getAllVersionsToBuildForProduct "${productToBuild}")
    fi
fi

# result table header
_resultsFile="/tmp/$$.results"
_reportPattern='%-23s| %-20s| %-20s| %-10s| %10s| %7s'

# Add header to results file
printf ' %-24s| %-20s| %-20s| %-10s| %10s| %7s\n' "PRODUCT" "VERSION" "SHIM" "JDK" "DURATION" "RESULT" > ${_resultsFile}
_totalStart=$(date '+%s')

_date=$(date +"%y%m%d")

returnCode=0

# Check if the given dryRun executes successfully
exec_cmd_or_fail() {
    eval "${dryRun} ${*}"
    result_code=${?}
    if test ${result_code} -ne 0; then
        echo_red "The following command resulted in an error: ${*}"
        returnCode=${result_code}
        _result=FAIL
        if test -n "${failFast}"; then
            exit ${result_code}
        fi
    fi
}

for _version in ${versionsToBuild}; do
    # if the list of shims was not provided as arguments, get the list from the versions file
    if test -z "${shimsToBuild}"; then
        _shimsToBuild=$(_getShimsToBuildForProductVersion "${productToBuild}" "${_version}")
    else
        _shimsToBuild=${shimsToBuild}
    fi

    _buildVersion="${_version}"

    # Check if a file named product.zip is present within the product directory.
    # If so, use a different buildVersion to differentiate the build from regular
    # builds that source from Artifactory. It is up to the product specific
    # Dockerfile to copy the product.zip into the build container.
    _overrideProductFile="${productToBuild}/tmp/product.zip"
    if test -f "${_overrideProductFile}"; then
        banner "Using file system location ${_overrideProductFile}"
        _buildVersion="${_version}-fsoverride"
    fi

    # In the snapshot pipeline, provide the latest version in the product's version.json
    # for the dependency check, as the snapshot version is not present in the versions.json
    if test -n "${PING_IDENTITY_SNAPSHOT}"; then
        dependency_check_version="${latestVersion}"
    else
        dependency_check_version="${_version}"
    fi
    _dependencies=$(_getDependenciesForProductVersion "${productToBuild}" "${dependency_check_version}")

    # iterate over the shims (default to alpine)
    for _shim in ${_shimsToBuild:-alpine}; do
        _start=$(date '+%s')
        _shimLongTag=$(_getLongTag "${_shim}")
        if test -z "${jvmsToBuild}"; then
            # Handle jvms to build for snapshot images
            if test -n "${PING_IDENTITY_SNAPSHOT}"; then
                _jvmsToBuild=$(_getJVMsToBuildForProductVersionShim "${productToBuild}" "${latestVersion}" "${_shim}")
                #TODO remove this al17 logic, once al17 is being built in product versions.json files
                if test "${productToBuild}" = "pingaccess" || test "${productToBuild}" = "pingfederate" && test "${_shim#*"alpine"}" != "${_shim}"; then
                    _jvmsToBuild="${_jvmsToBuild:+${_jvmsToBuild} }al17"
                fi
            else
                _jvmsToBuild=$(_getJVMsToBuildForProductVersionShim "${productToBuild}" "${_version}" "${_shim}")
            fi
        else
            _jvmsToBuild=${jvmsToBuild}
        fi

        for _jvm in ${_jvmsToBuild}; do
            fullTag="${_buildVersion}-${_shimLongTag}-${_jvm}-${CI_TAG}-${ARCH}"
            imageVersion="${_buildVersion}-${_shimLongTag}-${_jvm}"
            licenseVersion="$(_getLicenseVersion "${_version}")"

            _image="${FOUNDATION_REGISTRY}/${productToBuild}:${fullTag}"
            # Word-split is expected behavior for $progress. Disable shellcheck.
            # shellcheck disable=SC2086
            DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker image build \
                -t "${_image}" \
                ${progress} ${noCache} \
                --build-arg PRODUCT="${productToBuild}" \
                --build-arg REGISTRY="${FOUNDATION_REGISTRY}" \
                --build-arg DEPS="${DEPS_REGISTRY}" \
                --build-arg ARTIFACTORY_URL="${ARTIFACTORY_URL}" \
                --build-arg GIT_TAG="${CI_TAG}" \
                --build-arg JVM="${_jvm}" \
                --build-arg ARCH="${ARCH}" \
                --build-arg SHIM="${_shim}" \
                --build-arg SHIM_TAG="${_shimLongTag}" \
                --build-arg VERSION="${_buildVersion}" \
                --build-arg DATE="${_date}" \
                --build-arg IMAGE_VERSION="${imageVersion}" \
                --build-arg IMAGE_GIT_REV="${GIT_REV_MED}" \
                --build-arg LICENSE_VERSION="${licenseVersion}" \
                --build-arg LATEST_ALPINE_VERSION="3.19.0" \
                ${VERBOSE:+--build-arg VERBOSE="true"} \
                ${PING_IDENTITY_SNAPSHOT:+--build-arg SNAPSHOT_URL="${snapshot_url}"} \
                ${_dependencies} \
                "${CI_PROJECT_DIR}/${productToBuild}"

            _returnCode=${?}
            _stop=$(date '+%s')
            _duration=$((_stop - _start))
            if test ${_returnCode} -ne 0; then
                returnCode=${_returnCode}
                _result=FAIL
                if test -n "${failFast}"; then
                    banner "Build break for ${productToBuild} on ${_shim} for version ${_buildVersion}"
                    exit ${_returnCode}
                fi
            else
                _result=PASS
                if test -z "${IS_LOCAL_BUILD}"; then
                    exec_cmd_or_fail docker push "${_image}"
                    if test -n "${PING_IDENTITY_SNAPSHOT}" && test "${_jvm}" = "al11"; then
                        exec_cmd_or_fail docker tag "${_image}" "${FOUNDATION_REGISTRY}/${productToBuild}:latest-${ARCH}-$(date "+%m%d%Y")"
                        exec_cmd_or_fail docker push "${FOUNDATION_REGISTRY}/${productToBuild}:latest-${ARCH}-$(date "+%m%d%Y")"
                        exec_cmd_or_fail docker image rm -f "${FOUNDATION_REGISTRY}/${productToBuild}:latest-${ARCH}-$(date "+%m%d%Y")"
                        exec_cmd_or_fail docker tag "${_image}" "${FOUNDATION_REGISTRY}/${productToBuild}:${_version}-${ARCH}-$(date "+%m%d%Y")"
                        exec_cmd_or_fail docker push "${FOUNDATION_REGISTRY}/${productToBuild}:${_version}-${ARCH}-$(date "+%m%d%Y")"
                        exec_cmd_or_fail docker image rm -f "${FOUNDATION_REGISTRY}/${productToBuild}:${_version}-${ARCH}-$(date "+%m%d%Y")"
                        if test "${ARCH}" = "x86_64"; then
                            exec_cmd_or_fail docker tag "${_image}" "${FOUNDATION_REGISTRY}/${productToBuild}:latest"
                            exec_cmd_or_fail docker push "${FOUNDATION_REGISTRY}/${productToBuild}:latest"
                            exec_cmd_or_fail docker image rm -f "${FOUNDATION_REGISTRY}/${productToBuild}:latest"
                        fi
                    fi
                    exec_cmd_or_fail docker image rm -f "${_image}"
                fi
            fi
            append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "${productToBuild}" "${_buildVersion}" "${_shim}" "${_jvm}" "${_duration}" "${_result}"
        done
    done
done

# leave the runner without clutter
if test -z "${IS_LOCAL_BUILD}"; then
    imagesToClean=$(docker image ls -qf "reference=*/*/*${CI_TAG}*" | sort | uniq)
    # Word-split is expected behavior for $imagesToClean. Disable shellcheck.
    # shellcheck disable=SC2086
    test -n "${imagesToClean}" && exec_cmd_or_fail docker image rm -f ${imagesToClean}
    imagesToClean=$(docker image ls -qf "dangling=true")
    # Word-split is expected behavior for $imagesToClean. Disable shellcheck.
    # shellcheck disable=SC2086
    test -n "${imagesToClean}" && exec_cmd_or_fail docker image rm -f ${imagesToClean}
fi

cat ${_resultsFile}
rm ${_resultsFile}
_totalStop=$(date '+%s')
_totalDuration=$((_totalStop - _totalStart))
echo "Total duration: ${_totalDuration}s"
exit ${returnCode}
