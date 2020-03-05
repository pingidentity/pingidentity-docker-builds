#!/usr/bin/env bash
test -n "${VERBOSE}" && set -x
env

if test -z "${CI_COMMIT_REF_NAME}" ;then
    CI_PROJECT_DIR="$(cd $(dirname "${0}")/..;pwd)"
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

cd $( dirname ${0} )
export PING_IDENTITY_DEVOPS_USER
export PING_IDENTITY_DEVOPS_KEY
export ciTag
export FOUNDATION_REGISTRY
_totalStart=$( date '+%s' )
_resultsFile="/tmp/$$.results"
printf '%-38s|%10s|%10s\n' " TEST" " DURATION" " RESULT" > ${_resultsFile}
for _test in *.test.yml ;
do
    banner "Running ${_test} integration test"
    _start=$( date '+%s' )
    docker-compose -f simple_stack.test.yml up --exit-code-from sut --abort-on-container-exit
    _stop=$( date '+%s' )
    _duration=$(( _stop - _start ))
    _returnCode=${?}
    docker-compose -f simple_stack.test.yml down
    if test ${_returnCode} -ne 0 ;
    then
        returnCode=${_returnCode}
        _result="FAIL"
        printf '%-38s|%10s|'${FONT_RED}'%7s'${CHAR_CROSSMARK}${FONT_NORMAL}'\n' " ${_test}" " ${_duration}" "${_result}" >> ${_resultsFile}
    else    
        _result="PASS"
        printf '%-38s|%10s|'${FONT_GREEN}'%7s'${CHAR_CHECKMARK}${FONT_NORMAL}'\n' " ${_test}" " ${_duration}" "${_result}" >> ${_resultsFile}
    fi
done
cat ${_resultsFile}
rm ${_resultsFile}
_totalStop=$( date '+%s' )
_totalDuration=$(( _totalStop - _totalStart ))
echo "Total duration: ${_totalDuration}s"
exit $returnCode