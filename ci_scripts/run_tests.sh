#!/usr/bin/env bash
test -n "${VERBOSE}" && set -x

#
# Usage printing function
#
usage ()
{
    echo "${*}"
    cat <<END_USAGE
Usage: ${0} {options}
    where {options} include:
    -p, --product
        The name of the product for which to build a docker image
    -s, --shim
        the name of the operating system for which to build a docker image
    -v, --version
        the version of the product for which to build a docker image
        this setting overrides the versions in the version file of the target product
    --fast-fail
        verbose docker build not using docker buildkit
    --help
        Display general usage information
END_USAGE
    exit 99
}

if test -z "${CI_COMMIT_REF_NAME}" ;then
    # shellcheck disable=SC2046
    CI_PROJECT_DIR="$( cd $(dirname "${0}")/.. || exit 97 ; pwd )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts";
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

while ! test -z "${1}" ; do
    case "${1}" in
        -p|--product)
            if test -z "${2}" ; then
                usage "You must provide a product to build if you specify the ${1} option"
            fi
            shift
            product="${1}"
            ;;
        -s|--shim)
            if test -z "${2}" ; then
                usage "You must provide an OS shim if you specify the ${1} option"
            fi
            shift
            shimList="${shimList}${shimList:+ }${1}"
            ;;
        -v|--version)
            if test -z "${2}" ; then
                usage "You must provide a version to build if you specify the ${1} option"
            fi
            shift
            versions="${1}"
            ;;
        --fast-fail)
            fastFail=true
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

test -z "${product}" && usage "Providing a product is required"
! test -d "${product}" && echo "invalid product ${product}" && exit 98
! test -d "${product}/tests/" && echo "${product} has non tests" && exit 98

if test -z "${versions}" && test  -f "${product}"/versions.json ; 
then
#   versions=$(grep -v "^#" "${product}"/versions)
    versions=$( _getAllVersionsToBuildForProduct ${product} )
fi
test -n "${versions}" && notVersionless="true"

if test -n "${isLocalBuild}" ;
then
    set -a
    # shellcheck disable=SC1090
    . ~/.pingidentity/devops
    set +a
fi

# result table header    
_resultsFile="/tmp/$$.results"
printf '%-25s|%-10s|%-20s|%-38s|%10s|%7s\n' " PRODUCT" " VERSION" " SHIM" " TEST" " DURATION" " RESULT" > ${_resultsFile}
_totalStart=$( date '+%s' )
for _version in ${versions} ; 
do      
    if test -z "${shimList}" ;
    then
        _shimListForVersion=$( _getShimsToBuildForProductVersion ${product} ${_version} )
    fi

    for _shim in ${_shimListForVersion:-${shimList}} ; 
    do
        banner "Testing ${product} ${_version} on ${_shim}"
        # test this version of this product
        _shimTag=$( _getLongTag ${_shim} )
        _tag="${_version}${notVersionless:+-${_shimTag}}${ciTag:+-${ciTag}}"

        if test -z "${isLocalBuild}" ;
        then
            # docker pull "${FOUNDATION_REGISTRY}/${product}:${_tag}"
            if test "${product}" = "pingdatasync" ; 
            then
                # sync tests rely on the PingDirectory image being available too
                docker pull "${FOUNDATION_REGISTRY}/pingdirectory:${_tag}"
            fi
        fi
        
        # this is the loop where the actual test is run
        for _test in ${product}/tests/*.test.yml ; 
        do
            banner "Running test $( basename ${_test} ) on ${product} ${_version} ${_shim}"
            # sut = system under test
            _start=$( date '+%s' )
            env TAG=${_tag} REGISTRY=${FOUNDATION_REGISTRY} docker-compose -f ./"${_test}" up --exit-code-from sut --abort-on-container-exit
            _returnCode=${?}
            _stop=$( date '+%s' )
            _duration=$(( _stop - _start ))
            env TAG=${_tag} REGISTRY=${FOUNDATION_REGISTRY} docker-compose -f ./"${_test}" down
            if test ${_returnCode} -ne 0 ;
            then
                returnCode=${_returnCode}
                _result="FAIL"
                test -n "${fastFail}" && exit ${returnCode}
            else    
                _result="PASS"
            fi
            append_status "${_resultsFile}" ${_result} '%-24s|%-10s|%-20s|%-38s|%10s|%7s' " ${product}" " ${_version}" " ${_shim}" " $( basename ${_test} )" " ${_duration}" "${_result}"
        done
    done
done
cat ${_resultsFile}
rm ${_resultsFile}
_totalStop=$( date '+%s' )
_totalDuration=$(( _totalStop - _totalStart ))
echo "Total duration: ${_totalDuration}s"
exit $returnCode