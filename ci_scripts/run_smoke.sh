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
    -j, --jvm
        the id of the JVM to use to run the tests
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
            test -z "${2}" && usage "You must provide a product to build if you specify the ${1} option"
            shift
            product="${1}"
            ;;
        -s|--shim)
            test -z "${2}" && usage "You must provide an OS shim if you specify the ${1} option"
            shift
            shimList="${shimList}${shimList:+ }${1}"
            ;;
        -j|--jvm)
            test -z "${2}" && usage "You must provide a JVM id if you specify the ${1} option"
            shift
            jvmList="${jvmList:+${jvmList} }${1}"
            ;;
        -v|--version)
            test -z "${2}" && usage "You must provide a version to build if you specify the ${1} option"
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

returnCode=""

test -z "${product}" && usage "Providing a product is required"
! test -d "${product}" && echo "invalid product ${product}" && exit 98
! test -d "${product}/tests/" && echo "${product} has non tests" && exit 98

if test -z "${versions}" && test  -f "${product}"/versions.json ; 
then
#   versions=$(grep -v "^#" "${product}"/versions)
    versions=$( _getAllVersionsToBuildForProduct ${product} )
fi

if test -n "${isLocalBuild}" ;
then
    set -a
    # shellcheck disable=SC1090
    . ~/.pingidentity/devops
    set +a
fi

# result table header    
_resultsFile="/tmp/$$.results"
_headerPattern=' %-25s| %-12s| %-20s| %-10s| %-38s| %10s| %7s\n'
_reportPattern='%-24s| %-12s| %-20s| %-10s| %-38s| %10s| %7s'
# shellcheck disable=SC2059
printf "${_headerPattern}" "PRODUCT" "VERSION" "SHIM" "JVM" "TEST" "DURATION" "RESULT" > ${_resultsFile}
_totalStart=$( date '+%s' )
for _version in ${versions} ; 
do  
    test "${_version}" = "none" && _version=""
    if test -z "${shimList}" ;
    then
        _shimListForVersion=$( _getShimsToBuildForProductVersion ${product} ${_version} )
    fi

    for _shim in ${_shimListForVersion:-${shimList}} ; 
    do
        test "${_shim}" = "none" && _shim=""
        # test this version of this product
        _shimTag=$( _getLongTag ${_shim} )

        if test -z "${jvmList}" ; 
        then
            _jvms=$( _getJVMsToBuildForProductVersionShim ${product} ${_version} ${_shim})
        else
            _jvms=${jvmList}
        fi

        for _jvm in ${_jvms} ;
        do
            if test "${_jvm}" = "none" ;
            then
                _jvm=""
            else
                _jvmVersion=$( _getJVMVersionForID ${_jvm} )
            fi

            _tag="${_version}"
            test -n "${_shimTag}" && _tag="${_tag:+${_tag}-}${_shimTag}"
            test -n "${_jvm}" && _tag="${_tag:+${_tag}-}${_jvm}"
            test -n "${ciTag}" && _tag="${_tag:+${_tag}-}${ciTag}"

            if test -z "${isLocalBuild}" ;
            then
                docker pull "${FOUNDATION_REGISTRY}/${product}:${_tag}"
            fi
            
            # this is the loop where the actual test is run
            for _test in ${product}/tests/*.test.y*ml ; 
            do
                banner "Running test $( basename ${_test} ) on ${product}${_version:+ ${version}}${_shim:+ on ${shim}}${_jvm:+ with Java ${_jvmVersion}(${_jvm})}"
                # sut = system under test
                _start=$( date '+%s' )
                env TAG="${_tag}" REGISTRY="${FOUNDATION_REGISTRY}" docker-compose -f ./"${_test}" up --exit-code-from sut --abort-on-container-exit
                _returnCode=${?}
                _stop=$( date '+%s' )
                _duration=$(( _stop - _start ))
                env TAG="${_tag}" REGISTRY="${FOUNDATION_REGISTRY}" docker-compose -f ./"${_test}" down
                if test ${_returnCode} -ne 0 ;
                then
                    _result="FAIL"
                    test -n "${fastFail}" && exit ${returnCode}
                else
                    _result="PASS"
                fi
                # if all tests succeed, will add up to zero in the end  
                returnCode=$(( returnCode + _returnCode ))
                append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "${product}" "${_version:-none}" "${_shim:-none}" "${_jvm:-none}" "$( basename ${_test} )" "${_duration}" "${_result}"
            done
        done
    done
done

# leave the runner without clutter
if test -z "${isLocalBuild}" ;
then
    imagesToClean=$( docker image ls -qf "reference=*/*/*${ciTag}" | sort | uniq )
    # shellcheck disable=SC2086
    test -n "${imagesToClean}" && docker image rm -f ${imagesToClean}
fi

cat ${_resultsFile}
rm ${_resultsFile}
_totalStop=$( date '+%s' )
_totalDuration=$(( _totalStop - _totalStart ))
echo "Total duration: ${_totalDuration}s"
test -n "${returnCode}" && exit $returnCode

# something went wrong and no test were run if returnCode is empty
exit 1