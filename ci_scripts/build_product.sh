#!/usr/bin/env bash

#
# Usage printing function
#
usage ()
{
cat <<END_USAGE
Usage: ${0} {options}
    where {options} include:
    -d, --default-shim
        The name of the shim that will be tagged as default
    -p, --product
        The name of the product for which to build a docker image
    -s, --shim
        the name of the operating system for which to build a docker image
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

DOCKER_BUILDKIT=1
test -n "${VERBOSE}" && set -x
while ! test -z "${1}" ; 
do
    case "${1}" in
        -d|--default-shim)
            shift
            if test -z "${1}" ; then
                echo "You must provide a default OS Shim"
                usage
            fi
            defaultShim="${1}"
            ;;
        -p|--product)
            shift
            if test -z "${1}" ; then
                echo "You must provide a product to build"
                usage
            fi
            productToBuild="${1}"
            ;;
        -s|--shim)
            shift
            if test -z "${1}" ; then
                echo "You must provide an OS Shim"
                usage
            fi
            shimsToBuild="${shimsToBuild:+${shimsToBuild} }${1}"
            ;;
        -v|--version)
            shift
            if test -z "${1}" ; then
                echo "You must provide a version to build"
                usage
            fi
            versionsToBuild="${versionsToBuild:+${versionsToBuild} }${1}"
            ;;
        --no-build-kit)
            DOCKER_BUILDKIT=0
            noBuildKitArg="--no-build-kit"
            ;;
        --no-cache)
            noCache="--no-cache"
            ;;
        --verbose-build)
            progress="--progress plain"
            verboseBuildArg="--verbose-build"
            ;;
        --dry-run)
            dryRun="echo"
            ;;
        --fail-fast)
            failFast=true
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

if test -z "${productToBuild}" ; 
then
    echo "You must specify a product name to build, for example pingfederate or pingcentral"
    usage
fi

if test -z "${CI_COMMIT_REF_NAME}" ;
then
    CI_PROJECT_DIR="$(cd $(dirname "${0}")/..;pwd)"
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

if test -z "${versionsToBuild}" ; 
then
  versionsToBuild=$( _getVersionsFor ${productToBuild} )
fi


# result table header    
_resultsFile="/tmp/$$.results"
printf '%-25s|%-10s|%-20s|%10s|%7s\n' " PRODUCT" " VERSION" " SHIM" " DURATION" " RESULT" > ${_resultsFile}
_totalStart=$( date '+%s' )

returnCode=0
for _version in ${versionsToBuild} ; 
do
    # if the default shim has been provided as an argument, get it from the versions file
    if test -z "${defaultShim}" ; 
    then 
        _defaultShim=$( _getDefaultShimFor ${productToBuild} ${_version} )
    else
        _defaultShim="${defaultShim}"
    fi

    # if the list of shims was not provided as agruments, get the list from the versions file
    if test -z "${shimsToBuild}" ; 
    then 
        _shimsToBuild=$( _getShimsFor ${productToBuild} ${_version} ) 
    else
        _shimsToBuild=${shimsToBuild}
    fi

    if test -f "${productToBuild}/Product-staging" ;
    then
        _start=$( date '+%s' )
        # build the staging for each product so we don't need to download and stage the product each time
        DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker build \
            -f ${productToBuild}/Product-staging \
            -t "pingidentity/${productToBuild}:staging-${_version}" \
            ${progress} ${noCache} \
            --build-arg VERSION="${_version}" \
            --build-arg PRODUCT="${productToBuild}" \
            "${productToBuild}"
        _returnCode=${?}
        _stop=$( date '+%s' )
        _duration=$(( _stop - _start ))
        if test ${_returnCode} -ne 0 ; 
        then
            returnCode=${_returnCode}
            _result=FAIL
            if test -n "${failFast}" ;
            then
                banner "Build break for ${productToBuild} staging for version ${_version}"
                exit ${exitCode}
            fi
        else
            _result=PASS
        fi
        append_status "${_resultsFile}" ${_result} '%-25s|%-10s|%-20s|%10s|%7s' " ${productToBuild}" " ${_version}" " Staging" " ${_duration}" "${_result}"
    fi
    
    # iterate over the shims (default to alpine)
    for _shim in ${_shimsToBuild:-alpine} ; 
    do
        _start=$( date '+%s' )
        "${CI_SCRIPTS_DIR}/build_and_tag.sh" \
            --product "${productToBuild}" \
            --shim "${_shim}" \
            --default-shim ${_defaultShim:-alpine} \
            --version ${_version} \
            ${dryRun:+--dry-run} ${noCache} ${noBuildKitArg} ${verboseBuildArg}
        _returnCode=${?}
        _stop=$( date '+%s' )
        _duration=$(( _stop - _start ))
        if test ${_returnCode} -ne 0 ; 
        then
            returnCode=${_returnCode}
            _result=FAIL
            if test -n "${failFast}" ; 
            then
                banner "Build break for ${productToBuild} on ${_shim} for version ${_version}"
                exit ${exitCode}
            
            fi
        else
            _result=PASS
        fi
        append_status "${_resultsFile}" ${_result} '%-25s|%-10s|%-20s|%10s|%7s' " ${productToBuild}" " ${_version}" " ${_shim}" " ${_duration}" "${_result}"
    done
    _defaultShim=""
    _shimsToBuild=""
done
cat ${_resultsFile}
rm ${_resultsFile}
_totalStop=$( date '+%s' )
_totalDuration=$(( _totalStop - _totalStart ))
echo "Total duration: ${_totalDuration}s"
exit ${returnCode}