#!/usr/bin/env sh
test ! -z "${VERBOSE}" && ${VERBOSE} && set -x
usage ()
{
    cat <<END
    Usage: ${0} [product-name] {options}

    product-name: access federate directory datasync
                  the script will run all the test if nothing is provided

    where {options} include:
         -s, --summary: only provide summary of tests

END
}

summary=false
while ! test -z "${1}" ; do
    case "${1}" in
        access|federate|directory|datasync)
            testProduct="${testProduct} ${1}"
            ;;
        -s|--summary)
            summaryOutputDir="/tmp/test-local.$(date +%Y%m%d%H%M%S)"
            mkdir -p "${summaryOutputDir}"
            summary=true
            ;;
        *)
            usage
            exit 77
            ;;
    esac
    shift
done

testsToRun="${testProduct:-access federate directory datasync}"
if test ${summary} ; then
    echo "
###################################################################
# Running local tests for:
#
#    ${testsToRun}
# 
# Detailed logs can be found in directory:
#  
#    ${summaryOutputDir}/ping{product-name}.log
#
# Note: It may take up to several minutes for each
#       test to complete. To watch, simply tail
#       the log in a seperate window.
###################################################################
"

fi
# this is required to locally test against the edge version
export TAG=edge
p=ping
line='----------------------------------------'
for product in ${testsToRun} ; do
    fullProduct="${p}${product}"
    testCmd="docker-compose -f "${fullProduct}/build.test.yml" up --exit-code-from sut"
    cleanCmd="docker-compose -f "${fullProduct}/build.test.yml" down"

    startTest=$( date +%s )
    if $summary ; then
        msg="Testing ${fullProduct}"
        printf "%s %s " "${msg}" "${line:${#msg}}"
        $testCmd > "${summaryOutputDir}/${fullProduct}.log" 2> /dev/null
        testExitCode=${?}
    else
        $testCmd
        testExitCode=${?}
    fi
    endTest=$( date +%s )

    if test ${testExitCode} -eq 0 ; then
        $summary && printf '\e[1;32m%s\e[m (%5d sec)\n' "${testResult}" $((endTest-startTest))
        ! $summary && echo "TEST PASSED for ${fullProduct}"
    else
        $summary && printf '\e[1;31m%s\e[m (%5d sec)\n' "${testResult}" $((endTest-startTest))
        ! $summary && echo "TEST FAILURE for ${fullProduct}"
    fi
    $summary && ${cleanCmd}  > "${summaryOutputDir}/${fullProduct}.log" 2> /dev/null
    if ! ${summary} ; then
        ${cleanCmd}
        test $testExitCode -ne 0 && exit 1
    fi
done