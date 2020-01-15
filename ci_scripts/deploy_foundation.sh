#!/usr/bin/env bash
if test ! -z "${CI_COMMIT_REF_NAME}" ; then
    . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
    HERE=$(cd $(dirname "${0}");pwd)
    # shellcheck source=./ci_tools.lib.sh
    . "${HERE}/ci_tools.lib.sh"
fi

# TODO: clean old foundation images periodically. 

#this script is intended to push the pingfoundation images to 
# gcr as "latest". This script should ONLY be run from CI, and 
# ONLY on master. 
test ! $(git tag --points-at "$CI_COMMIT_SHA") && test ! $(git rev-parse --abbrev-ref "$CI_COMMIT_SHA") = "master" && echo "ERROR: are you sure this script should be running??" && exit 1

retag_and_deploy(){
  product=${1}
  tag=${2}
  if test -z ${tag} ; then
    docker pull "${FOUNDATION_REGISTRY}/${product}:${ciTag}"
    docker tag "${FOUNDATION_REGISTRY}/${product}:${ciTag}" "${FOUNDATION_REGISTRY}/${product}"
    docker push "${FOUNDATION_REGISTRY}/${product}"
    gcloud container images untag "${FOUNDATION_REGISTRY}/${product}:${ciTag}"
    docker rmi "${FOUNDATION_REGISTRY}/${product}:${ciTag}"
  else
    docker pull "${FOUNDATION_REGISTRY}/${product}:${tag}-${ciTag}"
    docker tag "${FOUNDATION_REGISTRY}/${product}:${tag}-${ciTag}" "${FOUNDATION_REGISTRY}/${product}:${tag}"
    docker push "${FOUNDATION_REGISTRY}/${product}:${tag}"
    gcloud container images untag "${FOUNDATION_REGISTRY}/${product}:${tag}-${ciTag}"
    docker rmi "${FOUNDATION_REGISTRY}/${product}:${tag}-${ciTag}"
  fi
}

retag_and_deploy "pingcommon"
retag_and_deploy "pingdatacommon"
retag_and_deploy "pingbase" "ubuntu"
retag_and_deploy "pingbase" "alpine"
retag_and_deploy "pingbase" "centos"

if test -z "${HERE}" ; then
    history | tail -100
fi