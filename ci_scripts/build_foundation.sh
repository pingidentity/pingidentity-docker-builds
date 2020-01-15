#!/usr/bin/env bash

HERE=$(cd $(dirname "${0}");pwd)
if test ! -z "${CI_COMMIT_REF_NAME}" ;then
    . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
    # shellcheck source=./ci_tools.lib.sh
    . "${HERE}/ci_tools.lib.sh"
fi

if test "${FOUNDATION_REGISTRY}" = "gcr.io/ping-identity" ; then
    docker container stop $(docker container ls -aq)
    docker container rm $(docker container ls -aq)
    docker image prune -f
    # docker rmi -f $(docker image ls --format '{{.Repository}} {{.ID}}' "pingidentity/*")
fi

set -e 

tag_and_push(){
    if test "${FOUNDATION_REGISTRY}" = "gcr.io/ping-identity" ; then
        docker tag "${1}" "${2}"
        docker push "${2}"
    fi
}

#build foundation and push to gcr for use in subsequent jobs. 
DOCKER_BUILDKIT=1 docker image build -t "pingidentity/pingcommon" ./pingcommon
tag_and_push "pingidentity/pingcommon" "${FOUNDATION_REGISTRY}/pingcommon:${ciTag}"

DOCKER_BUILDKIT=1 docker image build -t "pingidentity/pingdatacommon" ./pingdatacommon
tag_and_push "pingidentity/pingdatacommon" "${FOUNDATION_REGISTRY}/pingdatacommon:${ciTag}"

if test -z "${1}" ; then
    oses="alpine ubuntu centos"
else
    oses="${1}"
fi

for os in ${oses} ; do 
#   DOCKER_BUILDKIT=1 docker image build --build-arg SHIM=${os} -t "pingidentity/pingbase:${os}" ./pingbase
    docker image build --build-arg SHIM=${os} -t "pingidentity/pingbase:${os}" ./pingbase
    if test -n "${CI_COMMIT_REF_NAME}" ; then
        tag_and_push "pingidentity/pingbase:${os}" "${FOUNDATION_REGISTRY}/pingbase:${os}-${ciTag}"
    fi
done

echo "images built:"
docker images -f since=pingidentity/pingcommon:latest -f dangling=false | sed 's/^/#   /'

if test -n "${CI_COMMIT_REF_NAME}" ; then
    history | tail -100
fi