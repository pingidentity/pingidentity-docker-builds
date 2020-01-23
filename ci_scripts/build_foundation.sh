#!/usr/bin/env bash

HERE=$(cd $(dirname "${0}");pwd)
if test ! -z "${CI_COMMIT_REF_NAME}" ;then
    . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
    # shellcheck source=./ci_tools.lib.sh
    . "${HERE}/ci_tools.lib.sh"
fi

if test "${FOUNDATION_REGISTRY}" = "gcr.io/ping-identity" ; then
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
fi

set -e 

tag_and_push(){
    if test "${FOUNDATION_REGISTRY}" = "gcr.io/ping-identity" ; then
        docker tag "${1}" "${2}"
        docker push "${2}"
    fi
}

#build foundation and push to gcr for use in subsequent jobs. 
DOCKER_BUILDKIT=1 docker image build --no-cache -t "pingidentity/pingcommon" ./pingcommon
docker tag "pingidentity/pingcommon" "pingidentity/pingcommon:${ciTag}"
tag_and_push "pingidentity/pingcommon" "${FOUNDATION_REGISTRY}/pingcommon:${ciTag}"

DOCKER_BUILDKIT=1 docker image build -t "pingidentity/pingdatacommon" ./pingdatacommon
docker tag "pingidentity/pingdatacommon" "pingidentity/pingdatacommon:${ciTag}"
tag_and_push "pingidentity/pingdatacommon" "${FOUNDATION_REGISTRY}/pingdatacommon:${ciTag}"

if test -z "${1}" ; then
    oses="alpine ubuntu centos"
else
    oses="${1}"
fi

for os in ${oses} ; do 
    echo "################################################################################################"
    echo "#                       Building pingbase for ${os}                                            #"
    echo "################################################################################################"
    DOCKER_BUILDKIT=1 docker image build --build-arg SHIM=${os} -t "pingidentity/pingbase:${os}" ./pingbase
    if test -n "${CI_COMMIT_REF_NAME}" ; then
        docker tag "pingidentity/pingbase:${os}" "pingidentity/pingbase:${os}-${ciTag}"
        tag_and_push "pingidentity/pingbase:${os}" "${FOUNDATION_REGISTRY}/pingbase:${os}-${ciTag}"
    fi
done

echo "images built:"
docker images -f since=pingidentity/pingcommon:latest -f dangling=false | sed 's/^/#   /'
