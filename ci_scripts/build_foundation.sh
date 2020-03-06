#!/usr/bin/env bash
test -n "${VERSBOSE}" && set -x

tag_and_push(){
    if test "${FOUNDATION_REGISTRY}" = "gcr.io/ping-identity" ; then
        docker tag "${1}" "${2}"
        docker push "${2}"
    fi
}
_totalStart=$( date '+%s' )
DOCKER_BUILDKIT=1
while ! test -z "${1}" ; do
    case "${1}" in
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
            shimsToBuild="${shimsToBuild}${shimsToBuild:+ }${1}"
            ;;
        -v|--version)
            shift
            if test -z "${1}" ; then
                echo "You must provide a version to build"
                usage
            fi
            versionToBuild="${1}"
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
        --experimental)
            experimental=true
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

if test -z "${CI_COMMIT_REF_NAME}" ;then
    CI_PROJECT_DIR="$(cd $(dirname "${0}")/..;pwd)"
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

if test -z "${isLocalBuild}" ; then
    banner "CI FOUNDATION BUILD"
    # get the list of running containers.
    _containersList="$(docker container ls -q | sort | uniq)"
    # stop all running containers
    test -n "${_containersList}" && docker container stop ${_containersList}
    # get list of all stopped containers lingering
    _containersList="$(docker container ls -aq | sort | uniq)"
    # remove all containers
    test -n "${_containersList}" && docker container rm -f $(docker container ls -aq)
    # get the list of all images in the local repo
    _imagesList="$(docker image ls -q | sort | uniq)"
    test -n "${_imagesList}" && docker image rm -f ${_imagesList}

    # wipe everything clean
    docker container prune -f 
    docker image prune -f
    docker network prune
else
    banner "LOCAL FOUNDATION BUILD"
fi

#build foundation and push to gcr for use in subsequent jobs. 
DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker image build \
    ${progress} ${noCache} \
     -t "pingidentity/pingcommon" pingcommon
docker tag "pingidentity/pingcommon" "pingidentity/pingcommon:${ciTag}"
tag_and_push "pingidentity/pingcommon" "${FOUNDATION_REGISTRY}/pingcommon:${ciTag}"

DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker image build \
    ${progress} ${noCache} \
    -t "pingidentity/pingdatacommon" pingdatacommon
docker tag "pingidentity/pingdatacommon" "pingidentity/pingdatacommon:${ciTag}"
tag_and_push "pingidentity/pingdatacommon" "${FOUNDATION_REGISTRY}/pingdatacommon:${ciTag}"

if test -n "${shimsToBuild}" ; then
    shims=${shimsToBuild}
else
    if test -n "${productToBuild}" ; then
        if test -n "${versionToBuild}" ; then
            shims=$( _getShimsFor ${productToBuild} ${versionToBuild} )
        else
            shims=$( _getAllShimsFor ${productToBuild} )
        fi
    else
        shims=$( _getAllShims )
    fi
fi

# result table header    
_resultsFile="/tmp/$$.results"
printf '%-45s|%10s|%7s\n' " IMAGE" " DURATION" " RESULT" > ${_resultsFile}

for _shim in ${shims} ; do
    _shimTag=$( _getLongTag ${_shim})
    
    # find which JVMs to build for each supported SHIM
    _jvms=$( jq -r '[.versions[]|select(.shims[]|contains("'${_shim}'"))|.version]|unique|.[]' pingjvm/versions.json )
    for _jvm in ${_jvms} ;
    do
        banner "Building pingjvm for JDK ${_jvm} for ${_shim}"
        _start=$( date '+%s' )
        _jvm_from=$( jq -r '[.versions[]|select(.shims[]|contains("'${_shim}'"))| select(.version=="'${_jvm}'")|.from]|unique|.[]' pingjvm/versions.json )
        DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker image build \
            ${progress} ${noCache} \
            --build-arg SHIM=${_jvm_from} \
            -t "pingidentity/pingjvm:${_jvm}_${_shimTag}" pingjvm
        _returnCode=${?}
        _stop=$( date '+%s' )
        _duration=$(( _stop - _start ))
        if test ${_returnCode} -ne 0 ;
        then
            returnCode=${_returnCode}
            _result="FAIL"
        else
            _result="PASS"
            if test -z "${isLocalBuild}" ; then
                docker tag "pingidentity/pingjvm:${_jvm}_${_shimTag}" "pingidentity/pingjvm:${_jvm}_${_shimTag}-${ciTag}"
                tag_and_push "pingidentity/pingjvm:${_jvm}_${_shimTag}" "${FOUNDATION_REGISTRY}/pingjvm:${_jvm}_${_shimTag}-${ciTag}"
            fi    
        fi
        append_status "${_resultsFile}" ${_result} '%-44s|%10s|%7s' " pingjvm:${_jvm}_${_shimTag}" " ${_duration}" " ${_result}"
    done

    banner "Building pingbase for ${_shim}"
    # DOCKER_BUILDKIT=1 docker image build --build-arg SHIM=${_shim} -t "pingidentity/pingjvm:${_shimTag}" pingjvm
    _start=$( date '+%s' )
    DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker image build \
        ${progress} ${noCache} \
        --build-arg SHIM=${_shim} \
        ${experimental:+--build-arg BUILD_OPTIONS=--experimental} \
        -t "pingidentity/pingbase:${_shimTag}${experimental:+-ea}" pingbase
    _returnCode=${?}
    _stop=$( date '+%s' )
    _duration=$(( _stop - _start ))
    if test ${_returnCode} -ne 0 ;
    then
        returnCode=${_returnCode}
        _result="FAIL"
        # printf ${FONT_RED}${CHAR_CROSSMARK}'%-44s|%10s|%7s'${FONT_NORMAL}'\n' " pingbase:${_shimTag}${experimental:+-ea}" " ${_duration}" " ${_result}"  >> ${_resultsFile}
    else
        _result="PASS"
        if test -z "${isLocalBuild}" ; then
            docker tag "pingidentity/pingbase:${_shimTag}" "pingidentity/pingbase:${_shimTag}-${ciTag}"
            tag_and_push "pingidentity/pingbase:${_shimTag}" "${FOUNDATION_REGISTRY}/pingbase:${_shimTag}-${ciTag}"
        fi    
    fi
    append_status "${_resultsFile}" ${_result}  '%-44s|%10s|%7s' " pingbase:${_shimTag}${experimental:+-ea}" " ${_duration}" " ${_result}"
done

cat ${_resultsFile}
rm ${_resultsFile}
_totalStop=$( date '+%s' )
_totalDuration=$(( _totalStop - _totalStart ))
echo "Total duration: ${_totalDuration}s"
exit ${returnCode}