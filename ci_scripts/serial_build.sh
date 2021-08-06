#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# This build a set of images running through the steps of:
#
#     cleanup_docker.sh   - Cleaning up a docker environment
#     build_downloader.sh - Build the Ping Downloader Image
#     build_foundation.sh - Build the foundation images (pingbase, pingcommon, ...)
#     build_product.sh    - Build the product image itself
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
    --with-tests
        Execute smoke tests
    -s, --shim
        the name of the operating system for which to build a docker image
    -j, --jvm
        the id of the jvm to build
    -v, --version
        the version of the product for which to build a docker image
        this setting overrides the versions in the version file of the target product
    --verbose-build
        verbose docker build not using docker buildkit
    --dry-run
        does everything except actually call the docker command and prints it instead
    --help
        Display general usage information
END_USAGE
    exit 99
}

jvmsToBuild=""
buildOptions=""
shimsToBuild=""
versionsToBuild=""
PING_IDENTITY_SNAPSHOT=""
export PING_IDENTITY_SNAPSHOT
while ! test -z "${1}"; do
    case "${1}" in
        --dry-run)
            buildOptions="${buildOptions:+${buildOptions} }--dry-run"
            ;;
        --fail-fast)
            buildOptions="${buildOptions:+${buildOptions} }--fail-fast"
            ;;
        -j | --jvm)
            shift
            test -z "${1}" && usage "You must provide a JVM id"
            jvmsToBuild="${jvmsToBuild:+${jvmsToBuild} }--jvm ${1}"
            # buildOptions="${buildOptions:+${buildOptions} }--jvm ${1}"
            ;;
        --no-cache)
            buildOptions="${buildOptions:+${buildOptions} }--no-cache"
            ;;
        -p | --product)
            shift
            test -z "${1}" && usage "You must provide a product to build"
            _products="${_products:+${_products} }${1}"
            ;;
        -s | --shim)
            shift
            test -z "${1}" && usage "You must provide an OS Shim"
            shimsToBuild="${shimsToBuild:+${shimsToBuild} }--shim ${1}"
            ;;
        --snapshot)
            export PING_IDENTITY_SNAPSHOT="--snapshot"
            ;;
        --verbose-build)
            buildOptions="${buildOptions:+${buildOptions} }--verbose-build"
            ;;
        -v | --version)
            shift
            test -z "${1}" && usage "You must provide a version to build"
            versionsToBuild="${versionsToBuild:+${versionsToBuild} }--version ${1}"
            ;;
        --with-tests)
            _smokeTests=true
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
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

"${CI_SCRIPTS_DIR}/cleanup_docker.sh" full
"${CI_SCRIPTS_DIR}/build_product.sh" -p pingdownloader
# Word-split is expected behavior for $jvmsToBuild and $shimsToBuild. Disable shellcheck.
# shellcheck disable=SC2086
"${CI_SCRIPTS_DIR}/build_foundation.sh" ${jvmsToBuild} ${shimsToBuild}

test -z "${_products}" && _products="apache-jmeter ldap-sdk-tools pingaccess pingcentral pingdataconsole pingdatagovernance pingdatagovernancepap pingdatasync pingdirectory pingdirectoryproxy pingdelegator pingfederate pingtoolkit pingauthorize pingauthorizepap"

for p in ${_products}; do
    # Word-split is expected behavior for $buildOptions, $versionsToBuild, $jvmsToBuild, and $shimsToBuild. Disable shellcheck.
    # shellcheck disable=SC2086
    "${CI_SCRIPTS_DIR}/build_product.sh" -p "${p}" ${buildOptions} ${versionsToBuild} ${jvmsToBuild} ${shimsToBuild}
    test ${?} -ne 0 && failed=true && break

    if test -n "${_smokeTests}"; then
        # Word-split is expected behavior for $versionsToBuild, $jvmsToBuild, and $shimsToBuild. Disable shellcheck.
        # shellcheck disable=SC2086
        "${CI_SCRIPTS_DIR}/run_smoke.sh" -p "${p}" ${versionsToBuild} ${jvmsToBuild} ${shimsToBuild}
        test ${?} -ne 0 && failed=true && break
    fi
done
test -z "${failed}" && docker images
