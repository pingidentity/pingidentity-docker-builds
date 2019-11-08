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
  product=${1}
  docker pull "${FOUNDATION_REGISTRY}/${product}${ciTag}"
  docker tag "${FOUNDATION_REGISTRY}/${product}${ciTag}" "${FOUNDATION_REGISTRY}/${product//-/}"
  docker push "${FOUNDATION_REGISTRY}/${product//-/}s"
  gcloud container images untag "${FOUNDATION_REGISTRY}/${product}${ciTag}"
  docker rmi "${FOUNDATION_REGISTRY}/${product}${ciTag}"
}

retag_and_deploy "pingcommon:"
retag_and_deploy "pingdatacommon:"
retag_and_deploy "pingbase:ubuntu-"
retag_and_deploy "pingbase:alpine-"
retag_and_deploy "pingbase:centos-"

history | tail -100
