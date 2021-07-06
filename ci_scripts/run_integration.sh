#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# Runs integration tests located in integration_tests directory
#
test "${VERBOSE}" = "true" && set -x

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

_exitCode=""

cd "$(dirname "${0}")" || exit 97
export PING_IDENTITY_DEVOPS_USER
export PING_IDENTITY_DEVOPS_KEY

# create the integration_tests.properties to be used by tests
_integrationTestProps=/tmp/integration_tests.properties
envsubst < "${CI_PROJECT_DIR}/integration_tests/integration_tests.properties.subst" > ${_integrationTestProps}

_totalStart=$(date '+%s')
_resultsFile="/tmp/$$.results"
_reportPattern='%-57s| %10s| %10s'

#
# Create variables of format PINGDIRECTORY_LATEST=n.n.n.n and PINGDIRECTORY_SHIM=shim
# that will be exported and used by integration test docker-compose variables
#
for _productName in pingaccess pingcentral pingdataconsole pingdatagovernance pingdatagovernancepap pingdatasync pingdelegator pingdirectory pingdirectoryproxy pingfederate pingintelligence pingtoolkit pingauthorize pingauthorizepap; do
    #Get the latest version for each product and export it.
    _latestVar=$(echo -n "${_productName}_LATEST" | tr '[:lower:]' '[:upper:]')
    _latestVersion=$(_getLatestVersionForProduct "${_productName}")
    eval export "${_latestVar}"="${_latestVersion}"

    #Get the default shim for each latest product version and export it.
    _shimVar=$(echo -n "${_productName}_SHIM" | tr '[:lower:]' '[:upper:]')
    _defaultShim=$(_getDefaultShimForProductVersion "${_productName}" "${_latestVersion}")
    _defaultShimLongTag=$(_getLongTag "${_defaultShim}")
    eval export "${_shimVar}"="${_defaultShimLongTag}"
done
env | sort

# Add header to results file
printf ' %-58s| %10s| %10s\n' "TEST" "DURATION" "RESULT" > ${_resultsFile}
for _test in "${CI_PROJECT_DIR}/integration_tests/"${1:-*}.test.yml; do
    banner "Running ${_test} integration test"
    _start=$(date '+%s')

    export GIT_TAG="${CI_TAG}"
    export REGISTRY="${FOUNDATION_REGISTRY}"
    export DEPS="${DEPS_REGISTRY}"
    export JVM="${2:-az11}"
    # `docker pull` has less package dependencies than `docker-compose pull`
    # use docker pull to pull images before running `docker-compose up`
    if test -z "${IS_LOCAL_BUILD}"; then
        _testImages="$(grep '^\s*image' "${_test}" | sed 's/image://' | sort | uniq)"
        for _pullImage in ${_testImages}; do
            docker pull "$(eval echo "${_pullImage}")"
        done
    fi

    docker-compose -f "${_test}" up --exit-code-from sut --abort-on-container-exit
    _returnCode=${?}
    _stop=$(date '+%s')
    _duration=$((_stop - _start))

    docker-compose -f "${_test}" down
    if test ${_returnCode} -ne 0; then
        _result="FAIL"
    else
        _result="PASS"
    fi
    append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "${_test}" "${_duration}" "${_result}"
    _exitCode=$((_exitCode + _returnCode))
done

cat ${_resultsFile}
rm ${_integrationTestProps}
rm ${_resultsFile}
_totalStop=$(date '+%s')
_totalDuration=$((_totalStop - _totalStart))
echo "Total duration: ${_totalDuration}s"
test -n "${_exitCode}" && exit ${_exitCode}

# no test were run, this is likely an issue
exit 1
