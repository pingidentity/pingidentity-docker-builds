#!/usr/bin/env bash
set -e
product="${1}"

test -z "$CI_COMMIT_TAG" && test ! "${CI_COMMIT_REF_NAME}" = "master" && echo "ERROR: are you sure this script should be running??" && exit 1

if test ! -z "${CI_COMMIT_REF_NAME}" ; then
    . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
    HERE=$(cd $(dirname "${0}");pwd)
    # shellcheck source=./ci_tools.lib.sh
    . "${HERE}/ci_tools.lib.sh"
fi


tags=$(gcloud container images list-tags ${FOUNDATION_REGISTRY}/${product} --format="value(tags)" --filter=TAGS:"${ciTag}" | sed -e 's/,/ /g' )

for fullTag in $tags ; do
  docker pull "${FOUNDATION_REGISTRY}/${product}:$fullTag"
  dockerTag="$(echo $fullTag | sed -e 's/-${ciTag}//g')"
  docker tag "${FOUNDATION_REGISTRY}/${product}:$fullTag" "pingidentity/${product}:${dockerTag}"
  docker push "${FOUNDATION_REGISTRY}/${product}:${dockerTag}"
  test "$( echo ${fullTag} | grep ${ciTag})" && gcloud container images untag "${FOUNDATION_REGISTRY}/${product}:$fullTag"
done

# docker rmi -f $(docker image ls --filter=reference="pingidentity/${product}:*")
# docker rmi -f $(docker image ls --filter=reference="${FOUNDATION_REGISTRY}/${product}:*")

if test -n "${CI_COMMIT_REF_NAME}" ; then
    history | tail -100
fi