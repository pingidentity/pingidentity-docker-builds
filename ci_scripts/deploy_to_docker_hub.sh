#!/usr/bin/env bash
product="${1}"

test ! $(git tag --points-at "$CI_COMMIT_SHA") && test ! $(git rev-parse --abbrev-ref "$CI_COMMIT_SHA") = "master" && echo "ERROR: are you sure this script should be running??" && exit 1

if test ! -z "${CI_COMMIT_REF_NAME}" ; then
  . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
  # shellcheck source=~/projects/devops/pingidentity-docker-builds/ci_scripts/ci_tools.lib.sh
  . ${HOME}/projects/devops/pingidentity-docker-builds/ci_scripts/ci_tools.lib.sh
fi

tags=$(gcloud container images list-tags ${FOUNDATION_REGISTRY}/${product} --format="value(tags)" --filter=TAGS:"${ciTag}" | sed -e 's/,/ /g' )

for tag in $tags ; do
  docker pull "${FOUNDATION_REGISTRY}/${product}:$tag"
  dockerTag=$(echo "$tag" | sed -e "s/-${ciTag}//g")
  docker tag "${FOUNDATION_REGISTRY}/${product}:$tag" "pingidentity/${product}:${dockerTag}"
  docker push "pingidentity/${product}:${dockerTag}"
done

docker image rm -f "$(docker image ls --filter=reference=pingidentity/${product}:*)"
docker image rm -f "$(docker image ls --filter=reference=${FOUNDATION_REGISTRY}/${product}:*)"

history | tail -100