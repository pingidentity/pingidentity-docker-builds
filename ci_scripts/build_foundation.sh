#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# This script builds the foundation images:
#   - pingbase
#   - pingcommon
#   - pingdatacommon
#   - pingjvm
#
test "${VERBOSE}" = "true" && set -x

usage() {
    test -n "${*}" && echo "${*}"

    cat << END_USAGE
Usage: ${0} {options}
    where {options} include:
    -d, --default-shim
        The name of the shim that will be tagged as default
    -p, --product
        The name of the product for which to build a docker image
    -s, --shim
        the name of the operating system for which to build a docker image
    -j, --jvm
        the id of the jvm to build
    -v, --version
        the version of the product for which to build a docker image
        this setting overrides the versions in the version file of the target product
    --no-cache
        no docker cache
    --verbose-build
        verbose docker build using plain progress output
    --help
        Display general usage information
END_USAGE
    exit 99
}

_totalStart=$(date '+%s')
DOCKER_BUILDKIT=1
noCache=${DOCKER_BUILD_CACHE}
while test -n "${1}"; do
    case "${1}" in
        -p | --product)
            shift
            test -z "${1}" && usage "You must provide a product to build"
            productToBuild="${1}"
            ;;
        -s | --shim)
            shift
            test -z "${1}" && usage "You must provide an OS Shim"
            shimsToBuild="${shimsToBuild}${shimsToBuild:+ }${1}"
            ;;
        -j | --jvm)
            shift
            test -z "${1}" && usage "You must provide a JVM id"
            jvmsToBuild="${jvmsToBuild}${jvmsToBuild:+ }${1}"
            ;;
        -v | --version)
            shift
            test -z "${1}" && usage "You must provide a version to build"
            versionToBuild="${1}"
            ;;
        --no-cache)
            noCache="--no-cache"
            ;;
        --verbose-build)
            progress="--progress plain"
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

if test -z "${CI_COMMIT_REF_NAME}"; then
    CI_PROJECT_DIR="$(
        cd "$(dirname "${0}")/.." || exit 97
        pwd
    )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 98
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

# Check if the given command executes successfully
exec_cmd_or_fail() {
    eval "${*}"
    result_code=${?}
    if test ${result_code} -ne 0; then
        returnCode=${result_code}
        echo_red "The following command resulted in an error: ${*}"
        _result=FAIL
    fi
}

if test -z "${IS_LOCAL_BUILD}"; then
    banner "CI FOUNDATION BUILD"
    # get the list of running containers.
    _containersList="$(docker container ls -q | sort | uniq)"
    # stop all running containers
    # Word-split is expected behavior for $_containersList. Disable shellcheck.
    # shellcheck disable=SC2086
    test -n "${_containersList}" && exec_cmd_or_fail docker container stop ${_containersList}

    # get list of all stopped containers lingering
    _containersList="$(docker container ls -aq | sort | uniq)"
    # remove all containers
    # Word-split is expected behavior for $_containersList. Disable shellcheck.
    # shellcheck disable=SC2086
    test -n "${_containersList}" && exec_cmd_or_fail docker container rm -f ${_containersList}

    # get the list of all images in the local repo
    _imagesList="$(docker image ls -q | sort | uniq)"
    # Word-split is expected behavior for $_imagesList. Disable shellcheck.
    # shellcheck disable=SC2086
    test -n "${_imagesList}" && exec_cmd_or_fail docker image rm -f ${_imagesList}

    # wipe everything clean
    exec_cmd_or_fail docker image prune -f
    exec_cmd_or_fail docker network prune -f
else
    banner "LOCAL FOUNDATION BUILD"
fi

# result table header
_resultsFile="/tmp/$$.results"
_reportPattern='%-52s| %10s| %7s'

# Add header to results file
printf ' %-53s| %10s| %7s\n' "IMAGE" "DURATION" "RESULT" > ${_resultsFile}

#build foundation and push to gcr for use in subsequent jobs.
banner Building PING COMMON
_start=$(date '+%s')
_image="${FOUNDATION_REGISTRY}/pingcommon:${CI_TAG}-${ARCH}"

# Word-Split is expected behavior for $progress. Disable shellcheck.
# shellcheck disable=SC2086
DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker image build \
    ${progress} ${noCache} \
    --build-arg DEPS="${DEPS_REGISTRY}" \
    --build-arg ARTIFACTORY_URL="${ARTIFACTORY_URL}" \
    --build-arg LATEST_ALPINE_VERSION="3.20.2" \
    ${VERBOSE:+--build-arg VERBOSE="true"} \
    -t "${_image}" "${CI_PROJECT_DIR}/pingcommon"
_returnCode=${?}
_stop=$(date '+%s')
_duration=$((_stop - _start))
if test ${_returnCode} -ne 0; then
    returnCode=${_returnCode}
    _result="FAIL"
else
    _result="PASS"
    if test -z "${IS_LOCAL_BUILD}"; then
        banner "Pushing ${_image}"
        exec_cmd_or_fail docker push "${_image}"
    fi
    append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "pingcommon" "${_duration}" "${_result}"
fi
imagesToCleanup="${imagesToCleanup} ${_image}"

banner Building PING DATA COMMON
_start=$(date '+%s')
_image="${FOUNDATION_REGISTRY}/pingdatacommon:${CI_TAG}-${ARCH}"

# Word-Split is expected behavior for $progress. Disable shellcheck.
# shellcheck disable=SC2086
DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker image build \
    ${progress} ${noCache} \
    --build-arg REGISTRY="${FOUNDATION_REGISTRY}" \
    --build-arg GIT_TAG="${CI_TAG}" \
    --build-arg ARCH="${ARCH}" \
    -t "${_image}" "${CI_PROJECT_DIR}/pingdatacommon"
_returnCode=${?}
_stop=$(date '+%s')
_duration=$((_stop - _start))
if test ${_returnCode} -ne 0; then
    returnCode=${_returnCode}
    _result="FAIL"
else
    _result="PASS"
    if test -z "${IS_LOCAL_BUILD}"; then
        banner "Pushing ${_image}"
        exec_cmd_or_fail docker push "${_image}"
    fi
    append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "pingdatacommon" "${_duration}" "${_result}"
fi
imagesToCleanup="${imagesToCleanup} ${_image}"

if test -n "${PING_IDENTITY_SNAPSHOT}"; then
    # TODO: Fix artifactory caching issue. Shim is hardcoded to avoid incorrect arch pull from artifactory.
    shimsToBuild="alpine:3.20.2"
    if test "${ARCH}" = "x86_64"; then
        shimsToBuild="${shimsToBuild} redhat/ubi9-minimal:9.4-1194"
    fi
fi

if test -n "${shimsToBuild}"; then
    shims=${shimsToBuild}
else
    if test -n "${productToBuild}"; then
        if test -n "${versionToBuild}"; then
            shims=$(_getShimsToBuildForProductVersion "${productToBuild}" "${versionToBuild}")
        else
            shims=$(_getAllShimsForProduct "${productToBuild}")
        fi
    else
        if test -n "${jvmsToBuild}"; then
            for _jvm in ${jvmsToBuild}; do
                _shims="${_shims:+${_shims} }$(_getShimsToBuildForJVM "${_jvm}")"
            done
            shims=$(echo "${_shims}" | tr ' ' '\n' | sort | uniq | tr '\n' ' ')
        else
            shims=$(_getAllShims)
        fi
    fi
fi

for _shim in ${shims}; do
    _shimTag=$(_getLongTag "${_shim}")

    if test -z "${jvmsToBuild}"; then
        # find which JVMs to build for each supported SHIM
        _jvms=$(_getAllJVMsToBuildForShim "${_shim}")
    else
        _jvms=${jvmsToBuild}
    fi

    # If no jvm is resolved here, there was no -j flag provided and the resolved or provided shim does not match
    # any shims in any versions.json files.
    test -z "${_jvms}" &&
        echo_yellow "ERROR: No JVMs to build specified for ${_shim} on ${ARCH} in versions.json file." &&
        echo_yellow "Please update the product versions.json file or specify the desired jvm with the '-j' flag if this is not expected." &&
        break

    for _jvm in ${_jvms}; do
        # Check that the resolved JVM id is valid
        valid_jvms="$(_getAllJVMs)"
        jvm_is_valid="false"
        for valid_jvm in ${valid_jvms}; do
            if test "${_jvm}" = "${valid_jvm}"; then
                jvm_is_valid="true"
            fi
        done

        test "${jvm_is_valid}" = "false" &&
            echo_red "ERROR: The JVM ${_jvm} is not valid. The following IDs can be specified: " &&
            echo_red "${valid_jvms}" &&
            exit 1

        if test "${_jvm}" = "conoj" || test "${_jvm}" = "alnoj"; then
            continue
        fi
        banner "Building pingjvm for JDK ${_jvm} for ${_shim}"
        _start=$(date '+%s')
        _image="${FOUNDATION_REGISTRY}/pingjvm:${_jvm}-${_shimTag}-${CI_TAG}-${ARCH}"

        # Word-Split is expected behavior for $progress. Disable shellcheck.
        # shellcheck disable=SC2086
        DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker image build \
            ${progress} ${noCache} \
            ${VERBOSE:+--build-arg VERBOSE="true"} \
            --build-arg SHIM="${_shim}" \
            --build-arg DEPS="${DEPS_REGISTRY}" \
            --build-arg JVM_ID="${_jvm}" \
            -t "${_image}" "${CI_PROJECT_DIR}/pingjvm"
        _returnCode=${?}
        _stop=$(date '+%s')
        _duration=$((_stop - _start))
        if test ${_returnCode} -ne 0; then
            returnCode=${_returnCode}
            _result="FAIL"
        else
            _result="PASS"
            if test -z "${IS_LOCAL_BUILD}"; then
                banner "Pushing ${_image}"
                exec_cmd_or_fail docker push "${_image}"
            fi
        fi
        append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "pingjvm:${_jvm}-${_shimTag}" "${_duration}" "${_result}"
        imagesToCleanup="${imagesToCleanup} ${_image}"
    done
done

banner "Building pingbase"
_start=$(date '+%s')
_image="${FOUNDATION_REGISTRY}/pingbase:${CI_TAG}-${ARCH}"

# Word-Split is expected behavior for $progress. Disable shellcheck.
# shellcheck disable=SC2086
DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker image build \
    ${progress} ${noCache} \
    -t "${_image}" "${CI_PROJECT_DIR}/pingbase"
_returnCode=${?}
_stop=$(date '+%s')
_duration=$((_stop - _start))
if test ${_returnCode} -ne 0; then
    returnCode=${_returnCode}
    _result="FAIL"
else
    _result="PASS"
    if test -z "${IS_LOCAL_BUILD}"; then
        banner "Pushing ${_image}"
        exec_cmd_or_fail docker push "${_image}"
    fi
fi
append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "pingbase" "${_duration}" "${_result}"
imagesToCleanup="${imagesToCleanup} ${_image}"

# leave runner without clutter
# Word-Split is expected behavior for $imagesToCleanup. Disable shellcheck.
# shellcheck disable=SC2086
test -z "${IS_LOCAL_BUILD}" && exec_cmd_or_fail docker image rm -f ${imagesToCleanup}

cat ${_resultsFile}
rm ${_resultsFile}
_totalStop=$(date '+%s')
_totalDuration=$((_totalStop - _totalStart))
echo "Total duration: ${_totalDuration}s"
test -z "${returnCode}" && returnCode=0
exit "${returnCode}"
