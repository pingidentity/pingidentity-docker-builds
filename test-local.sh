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

p=ping
line='----------------------------------------'
for product in ${testsToRun} ; do

    fullProduct="${p}${product}"
    testCmd="docker-compose -f "${fullProduct}/build.test.yml" up --exit-code-from sut"
    cleanCmd="docker-compose -f "${fullProduct}/build.test.yml" down"

    startTest=$( date +%s )
    if test $summary ; then
        msg="Testing ${fullProduct}"
        printf "%s %s " "${msg}" "${line:${#msg}}"
        

        $testCmd > "${summaryOutputDir}/${fullProduct}.log" 2> /dev/null
    else
        $testCmd
    fi
    endTest=$( date +%s )


    if test ${?} -ne 0 ; then
        if test $summary ; then
            testResult="FAILED"
        else
            echo "TEST FAILURE for ${fullProduct}"
            exit 1
        fi
    else 
        if test $summary ; then
            testResult="PASSED"
        else
            echo "TEST PASSED for ${fullProduct}"
        fi
    fi

    if test $summary ; then
        if test "${testResult}" = "PASSED" ; then
            printf '\e[1;32m%s\e[m (%5d sec)\n' "${testResult}" $((endTest-startTest))
        else
            printf '\e[1;31m%s\e[m (%5d sec)\n' "${testResult}" $((endTest-startTest))
        fi
    fi

    if test $summary ; then
        ${cleanCmd}  > "${summaryOutputDir}/${fullProduct}.log" 2> /dev/null
    else
        ${cleanCmd}
    fi
    
done