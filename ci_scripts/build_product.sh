#!/usr/bin/env bash
test -n "${VERBOSE}" && set -x

#
# Usage printing function
#
usage ()
{
        test -n "${*}" && echo "${*}"
    cat <<END_USAGE
Usage: ${0} {options}
    where {options} include:
    -p, --product
        The name of the product for which to build a docker image
    -s, --shim
        the name of the operating system for which to build a docker image
    -j, --jvm
        the id of the jvm to build
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

# export PING_IDENTITY_SNAPSHOT=--snapshot to trigger snapshot build
DOCKER_BUILDKIT=${DOCKER_BUILDKIT:-1}
noCache=${DOCKER_BUILD_CACHE}
while ! test -z "${1}" ; 
do
    case "${1}" in
        -p|--product)
            shift
            test -z "${1}" && usage "You must provide a product to build"
            productToBuild="${1}"
            ;;
        -s|--shim)
            shift
            test -z "${1}" && usage "You must provide an OS Shim"
            shimsToBuild="${shimsToBuild:+${shimsToBuild} }${1}"
            ;;
        -j|--jvm)
            shift
            test -z "${1}" && usage "You must provide a JVM id"
            jvmsToBuild="${jvmsToBuild:+${jvmsToBuild} }${1}"
            ;;
        -v|--version)
            shift
            test -z "${1}" && usage "You must provide a version to build"
            versionsToBuild="${versionsToBuild:+${versionsToBuild} }${1}"
            ;;
        --no-build-kit)
            DOCKER_BUILDKIT=0
            ;;
        --no-cache)
            noCache="--no-cache"
            ;;
        --verbose-build)
            progress="--progress plain"
            ;;
        --dry-run)
            dryRun="echo"
            ;;
        --fail-fast)
            failFast=true
            ;;
        --snapshot)
            export PING_IDENTITY_SNAPSHOT="--snapshot"
            ;;
        --help)
            usage
            ;;
        *)
            usage "Unrecognized option"
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
    # shellcheck disable=SC2046 
    CI_PROJECT_DIR="$( cd $( dirname "${0}" )/.. || exit 97 ; pwd )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

if test -n "${PING_IDENTITY_SNAPSHOT}" ;
then
    case "${productToBuild}" in
        pingdirectory|pingdirectoryproxy|pingdatasync|pingdatagovernance|pingdatagovernancepap|pingfederate|pingcentral|pingaccess)
            ;;
        *)
            echo Snapshot not supported yet 
            exit 0
            ;;
    esac
fi

if test -z "${versionsToBuild}" ;
then
    if test -n "${PING_IDENTITY_SNAPSHOT}" ;
    then
        versionsToBuild=$( _getLatestSnapshotVersionForProduct ${productToBuild} )
        shimsToBuild="alpine"
        jvmsToBuild="az11"
    else
        versionsToBuild=$( _getAllVersionsToBuildForProduct ${productToBuild} )
    fi
fi

if test -z "${isLocalBuild}" && test ${DOCKER_BUILDKIT} -eq 1 ;
then
    docker pull ${FOUNDATION_REGISTRY}/pingcommon:${ciTag} 
    docker pull ${FOUNDATION_REGISTRY}/pingdatacommon:${ciTag}
fi

# result table header    
_resultsFile="/tmp/$$.results"
_headerPattern=' %-24s| %-20s| %-20s| %-10s| %10s| %7s\n'
_reportPattern='%-23s| %-20s| %-20s| %-10s| %10s| %7s'
printf "${_headerPattern}" "PRODUCT" "VERSION" "SHIM" "JDK" "DURATION" "RESULT" > ${_resultsFile}
_totalStart=$( date '+%s' )

_date=$( date +"%y%m%d" )

returnCode=0
for _version in ${versionsToBuild} ; 
do
    # # if the default shim has been provided as an argument, get it from the versions file
    # if test -z "${defaultShim}" ; 
    # then 
    #     _defaultShim=$( _getDefaultShimForProductVersion ${productToBuild} ${_version} )
    # else
    #     _defaultShim="${defaultShim}"
    # fi

    # if the list of shims was not provided as agruments, get the list from the versions file
    if test -z "${shimsToBuild}" ; 
    then 
        _shimsToBuild=$( _getShimsToBuildForProductVersion ${productToBuild} ${_version} ) 
    else
        _shimsToBuild=${shimsToBuild}
    fi

    if test -f "${productToBuild}/Product-staging" ;
    then
        _start=$( date '+%s' )
        _dependencies=$( _getDependenciesForProductVersion ${productToBuild} ${_version} )
        _image="${FOUNDATION_REGISTRY}/${productToBuild}:staging-${_version}-${ciTag}"
        # build the staging for each product so we don't need to download and stage the product each time
        DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker build \
            -f ${productToBuild}/Product-staging \
            -t ${_image} \
            ${progress} ${noCache} \
            --build-arg REGISTRY="${FOUNDATION_REGISTRY}" \
            --build-arg GIT_TAG="${ciTag}" \
            --build-arg DEVOPS_USER="${PING_IDENTITY_DEVOPS_USER}" \
            --build-arg DEVOPS_KEY="${PING_IDENTITY_DEVOPS_KEY}" \
            --build-arg VERSION="${_version}" \
            --build-arg PRODUCT="${productToBuild}" \
            ${PING_IDENTITY_SNAPSHOT:+--build-arg PING_IDENTITY_SNAPSHOT="${PING_IDENTITY_SNAPSHOT}"} \
            ${PING_IDENTITY_GITLAB_TOKEN:+--build-arg PING_IDENTITY_GITLAB_TOKEN="${PING_IDENTITY_GITLAB_TOKEN}"} \
            ${_dependencies} \
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
                exit ${_returnCode}
            fi
        else
            _result=PASS
        fi
        append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "${productToBuild}" "${_version}" "Staging" "N/A" "${_duration}" "${_result}"
        imagesToClean="${imagesToClean} ${_image}"
    fi
    
    # iterate over the shims (default to alpine)
    for _shim in ${_shimsToBuild:-alpine} ; 
    do
        _start=$( date '+%s' )
        _shimLongTag=$( _getLongTag "${_shim}" )
        if test -z "${jvmsToBuild}" ;
        then
            _jvmsToBuild=$( _getJVMsToBuildForProductVersionShim ${productToBuild} ${_version} ${_shim} )
        else
            _jvmsToBuild=${jvmsToBuild}
        fi

        for _jvm in ${_jvmsToBuild} ;
        do
            if test -z "${isLocalBuild}" && test ${DOCKER_BUILDKIT} -eq 1 ;
            then
                docker pull "${FOUNDATION_REGISTRY}/pingjvm:${_jvm}_${_shimLongTag}-${ciTag}"
            fi

            fullTag="${_version}-${_shimLongTag}-${_jvm}-${ciTag}"
            imageVersion="${productToBuild}-${_shimLongTag}-${_jvm}-${_version}-${_date}-${gitRevShort}"
            licenseVersion="$( _getLicenseVersion ${_version} )"

            _image="${FOUNDATION_REGISTRY}/${productToBuild}:${fullTag}"
            DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker build \
                -t ${_image} \
                ${progress} ${noCache} \
                --build-arg PRODUCT="${productToBuild}" \
                --build-arg REGISTRY="${FOUNDATION_REGISTRY}" \
                --build-arg GIT_TAG="${ciTag}" \
                --build-arg JVM="${_jvm}" \
                --build-arg SHIM="${_shim}" \
                --build-arg SHIM_TAG="${_shimLongTag}" \
                --build-arg VERSION="${_version}" \
                --build-arg IMAGE_VERSION="${imageVersion}" \
                --build-arg IMAGE_GIT_REV="${gitRevLong}" \
                --build-arg LICENSE_VERSION="${licenseVersion}" \
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
                    banner "Build break for ${productToBuild} on ${_shim} for version ${_version}"
                    exit ${_returnCode}
                fi
            else
                _result=PASS
                if test -z "${isLocalBuild}" ;
                then
                    ${dryRun} docker push "${_image}"
                    if test -n "${PING_IDENTITY_SNAPSHOT}" ;
                    then
                        ${dryRun} docker tag ${_image} "${FOUNDATION_REGISTRY}/${productToBuild}:latest"
                        ${dryRun} docker push "${FOUNDATION_REGISTRY}/${productToBuild}:latest"
                        ${dryRun} docker image rm -f "${FOUNDATION_REGISTRY}/${productToBuild}:latest"
                    fi
                    ${dryRun} docker image rm -f ${_image}
                fi
            fi
            append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "${productToBuild}" "${_version}" "${_shim}" "${_jvm}" "${_duration}" "${_result}"
        done
    done
done

# leave the runner without clutter
if test -z "${isLocalBuild}" ;
then
    imagesToClean=$( docker image ls -qf "reference=*/*/*${ciTag}" | sort | uniq )
    test -n "${imagesToClean}" && ${dryRun} docker image rm -f ${imagesToClean}
    imagesToClean=$( docker image ls -qf "dangling=true" )
    test -n "${imagesToClean}" && ${dryRun} docker image rm -f ${imagesToClean}
fi

cat ${_resultsFile}
rm ${_resultsFile}
_totalStop=$( date '+%s' )
_totalDuration=$(( _totalStop - _totalStart ))
echo "Total duration: ${_totalDuration}s"
exit ${returnCode}