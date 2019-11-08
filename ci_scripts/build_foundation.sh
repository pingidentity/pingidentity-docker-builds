#!/usr/bin/env bash


if test ! -z "${CI_COMMIT_REF_NAME}" ;then
  . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
  # shellcheck source=~/projects/devops/pingidentity-docker-builds/ci_scripts/ci_tools.lib.sh
  . ${HOME}/projects/devops/pingidentity-docker-builds/ci_scripts/ci_tools.lib.sh
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
docker image build -t "pingidentity/pingcommon" ./pingcommon
tag_and_push "pingidentity/pingcommon" "${FOUNDATION_REGISTRY}/pingcommon:${ciTag}"

docker image build -t "pingidentity/pingdatacommon" ./pingdatacommon
tag_and_push "pingidentity/pingdatacommon" "${FOUNDATION_REGISTRY}/pingdatacommon:${ciTag}"

if test -z ${1} ; then
  oses="alpine ubuntu centos"
else
  oses="${1}"
fi

for os in ${oses} ; do 
  docker image build --build-arg SHIM=${os} -t "pingidentity/pingbase:${os}" ./pingbase
  tag_and_push "pingidentity/pingbase:${os}" "${FOUNDATION_REGISTRY}/pingbase:${os}-${ciTag}"
done


echo "images built:"
docker images -f since=pingidentity/pingcommon:latest -f dangling=false | sed 's/^/#   /'

history | tail -60