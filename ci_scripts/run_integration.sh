#!/usr/bin/env bash
test -n "${VERBOSE}" && set -x
env

if test -z "${CI_COMMIT_REF_NAME}" ;then
    # shellcheck disable=SC2046 
    CI_PROJECT_DIR="$( cd $( dirname "${0}" )/.. || exit 97 ; pwd )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR}/ci_scripts"
# shellcheck source=../ci_scripts/ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

_exitCode=""

# shellcheck disable=SC2046
cd $( dirname "${0}" ) || exit 97
export PING_IDENTITY_DEVOPS_USER
export PING_IDENTITY_DEVOPS_KEY
_totalStart=$( date '+%s' )
_resultsFile="/tmp/$$.results"
_headerPattern=' %-58s| %10s| %10s\n'
_reportPattern='%-57s| %10s| %10s'
printf "${_headerPattern}" "TEST" "DURATION" "RESULT" > ${_resultsFile}
for _test in ${CI_PROJECT_DIR}/integration_tests/${1:-*}.test.yml ;
do
    banner "Running ${_test} integration test"
    _start=$( date '+%s' )
    GIT_TAG=${ciTag} REGISTRY=${FOUNDATION_REGISTRY} docker-compose -f ${_test} up --exit-code-from sut --abort-on-container-exit
    _returnCode=${?}
    _stop=$( date '+%s' )
    _duration=$(( _stop - _start ))
    GIT_TAG=${ciTag} REGISTRY=${FOUNDATION_REGISTRY} docker-compose -f ${_test} down
    if test ${_returnCode} -ne 0 ;
    then
        _result="FAIL"
    else    
        _result="PASS"
    fi
    append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "${_test}" "${_duration}" "${_result}"
    _exitCode=$(( _exitCode + _returnCode ))
done

cat ${_resultsFile}
rm ${_resultsFile}
_totalStop=$( date '+%s' )
_totalDuration=$(( _totalStop - _totalStart ))
echo "Total duration: ${_totalDuration}s"
test -n "${_exitCode}" && exit ${_exitCode}

# no test were run, this is likely an issue
exit 1