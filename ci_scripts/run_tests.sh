#!/usr/bin/env bash
# TODO REMOVE THIS
# product=${1}
# shift
# shimList=${*}

if test -z "${CI_COMMIT_REF_NAME}" ;
then
    CI_PROJECT_DIR="$(cd $(dirname "${0}")/..;pwd)"
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR}/ci_scripts"   
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"


pull_and_tag(){
    if test "${FOUNDATION_REGISTRY}" = "gcr.io/ping-identity" ; 
    then
        docker pull "${1}"
        docker tag "${1}" "${2}"
    fi
    #image is expected to be there if not on CI
}


while ! test -z "${1}" ; do
    case "${1}" in
        -p|--product)
            shift
            if test -z "${1}" ; then
                echo "You must provide a product to build"
                usage
            fi
            product="${1}"
            ;;
        -s|--shim)
            shift
            if test -z "${1}" ; then
                echo "You must provide an OS Shim"
                usage
            fi
            shimList="${shimList}${shimList:+ }${1}"
            ;;
        -v|--version)
            shift
            if test -z "${1}" ; then
                echo "You must provide a version to build"
                usage
            fi
            versions="${1}"
            ;;
        --fast-fail)
            fast_fail=true
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unrecognized option"
            usage
            ;;
    esac
    shift
done

# assume tests will pass unless proven otherwise
returnCode=0

if test -z "${versions}" && test  -f "${product}"/versions.json ; 
then
#   versions=$(grep -v "^#" "${product}"/versions)
  versions=$( _getVersionsFor ${product} )
  notVersionless="true"
fi

# result table header    
_resultsFile="/tmp/$$.results"
printf '%-25s|%-10s|%-20s|%-38s|%10s|%7s\n' " PRODUCT" " VERSION" " SHIM" " TEST" " DURATION" " RESULT" > ${_resultsFile}
_totalStart=$( date '+%s' )
for _version in ${versions} ; 
do      
    if test -z "${shimList}" ;
    then
        _shimListForVersion=$( _getShimsFor ${product} ${_version} )
    fi

    for _shim in ${_shimListForVersion:-${shimList}} ; 
    do
        banner "Testing ${product} ${_version} on ${_shim}"
        # test this version of this product
        _shimTag=$( _getLongTag ${_shim} )

        if test -z "${isLocalBuild}" ;
        then
            # runner build
            _tag="${_version}${notVersionless:+-${_shimTag}}-edge${ciTag:+-${ciTag}}"
            # since the build is distributed, the required image may have been built on a different
            # runner and not be in the local repo
            # we pull it from gcr
            pull_and_tag "${FOUNDATION_REGISTRY}/${product}:${_tag}" "pingidentity/${product}:${_tag}"
            if test "${product}" = "pingdatasync" ; 
            then
                # sync tests rely on the PingDirectory image being available too
                pull_and_tag "${FOUNDATION_REGISTRY}/pingdirectory:${_tag}" "pingidentity/pingdirectory:${_tag}"
            fi
        else
            # local build
            _tag="${_version}${notVersionless:+-${_shimTag}}-edge"
        fi
        
        # this is the loop where the actual test is run
        for _test in ${product}/*.test.yml ; 
        do
            banner "Running test $( basename ${_test} ) on ${product} ${_version} ${_shim}"
            # sut = system under test
            _start=$( date '+%s' )
            env TAG=${_tag} docker-compose -f ./"${_test}" up --exit-code-from sut --abort-on-container-exit
            _returnCode=${?}
            _stop=$( date '+%s' )
            _duration=$(( _stop - _start ))
            env TAG=${_tag} docker-compose -f ./"${_test}" down
            if test ${_returnCode} -ne 0 ;
            then
                returnCode=${_returnCode}
                _result="FAIL"
                printf '%-25s|%-10s|%-20s|%-38s|%10s|'${FONT_RED}'%7s'${CHAR_CROSSMARK}${FONT_NORMAL}'\n' " ${product}" " ${_version}" " ${_shim}" " $( basename ${_test} )" " ${_duration}" "${_result}" >> ${_resultsFile}
                test -n ${fast_fail} && exit ${returnCode}
            else    
                _result="PASS"
                printf '%-25s|%-10s|%-20s|%-38s|%10s|'${FONT_GREEN}'%7s'${CHAR_CHECKMARK}${FONT_NORMAL}'\n' " ${product}" " ${_version}" " ${_shim}" " $( basename ${_test} )" " ${_duration}" "${_result}" >> ${_resultsFile}
            fi
        done
    done
done
cat ${_resultsFile}
rm ${_resultsFile}
_totalStop=$( date '+%s' )
_totalDuration=$(( _totalStop - _totalStart ))
echo "Total duration: ${_totalDuration}s"
exit $returnCode