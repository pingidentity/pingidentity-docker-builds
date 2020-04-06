#!/usr/bin/env bash
test -n "${VERBOSE}" && set -x

if test -z "${CI_COMMIT_REF_NAME}" ;then
    # shellcheck disable=SC2046
    CI_PROJECT_DIR="$( cd $(dirname "${0}")/.. || exit 97 ; pwd )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts";
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

images="$(gcloud container images list --repository=gcr.io/ping-gte)"
for image in ${images:5} ; do
  echo "RUNNING FOR IMAGE: $image"
  tags=$(gcloud container images list-tags $image --format="value(tags)" --filter=TAGS:"${ciTag}" | sed -e 's/,/ /g' )
  for tag in $tags ; do
    echo "RUNNING FOR TAG: $tag"
    gcloud container images untag "$image:$tag" --quiet
  done
  digests="$(gcloud container images list-tags $image --filter='-tags:*'  --format='get(digest)' --limit=1000)"
  for digest in $digests ; do
    echo "RUNNING FOR DIGEST: $digest"
    gcloud container images delete $image@$digest --quiet
  done
done

exit 0