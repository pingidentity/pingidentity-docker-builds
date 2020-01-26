#!/bin/bash
_summaryCode=0
_resultSummary=""
_start=$( date '+%s' )
for _os in alpine centos ubuntu ; do
    for _version in $(awk '$0!~/^#/{print $1}' versions) ; do
        for _test in *.test.yml ; do
            _tag="${_version}-${_os}-edge"
            TAG="${_tag}" docker-compose -f ${_test} up --exit-code-from sut --abort-on-container-exit 
            _returnCode="${?}"
	        _resultSummary="${_resultSummary}${_resultSummary:+\n}${_tag} : "
            if test ${_returnCode} -eq 0 ; then
	            _resultSummary="${_resultSummary}OK"
            else
	            _resultSummary="${_resultSummary}ERROR"
                _summaryCode=1
            fi
            TAG="${_tag}" docker-compose -f ${_test} down
            # test ${_returnCode} -ne 0 && exit 1
        done
    done
done
_end=$( date '+%s' )
printf "runtime: %s seconds\n" $(( _end - _start )) 
printf ${_resultSummary}
exit ${_summaryCode}