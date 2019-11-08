#!/usr/bin/env bash

if test ! -z "${CI_COMMIT_REF_NAME}" ; then
  . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
  # shellcheck source=~/projects/devops/pingidentity-docker-builds/ci_scripts/ci_tools.lib.sh
  . ${HOME}/projects/devops/pingidentity-docker-builds/ci_scripts/ci_tools.lib.sh
fi

# TODO: clean old foundation images periodically. 

#this script is intended to push the pingfoundation images to 
# gcr as "latest". This script should ONLY be run from CI, and 
# ONLY on master. 
test ! $(git tag --points-at "$CI_COMMIT_SHA") && test ! $(git rev-parse --abbrev-ref "$CI_COMMIT_SHA") = "master" && echo "ERROR: are you sure this script should be running??" && exit 1

FOUNDATION_REGISTRY="gcr.io/ping-identity"
gitRevShort=$( git rev-parse --short=4 "$CI_COMMIT_SHA" )
gitRevLong=$( git rev-parse "$CI_COMMIT_SHA" )
ciTag="${CI_COMMIT_REF_NAME}-${CI_COMMIT_SHORT_SHA}"

retag_and_deploy(){
  docker pull "${FOUNDATION_REGISTRY}/${1}${ciTag}"
  docker tag "${FOUNDATION_REGISTRY}/${1}${ciTag}" "${FOUNDATION_REGISTRY}/${1}"
  docker push "${FOUNDATION_REGISTRY}/${1}"
  gcloud container images delete "${FOUNDATION_REGISTRY}/${1}${ciTag}"
  docker rmi -f "${FOUNDATION_REGISTRY}/${1}${ciTag}"
  docker rmi -f "${FOUNDATION_REGISTRY}/${1}"
}

retag_and_deploy "pingcommon:"
retag_and_deploy "pingdatacommon:"
retag_and_deploy "pingbase:ubuntu-"
retag_and_deploy "pingbase:alpine-"
retag_and_deploy "pingbase:centos-"

history | tail -100
