#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# This script cleans up the Google Cloud Registry (gcr)
#
test "${VERBOSE}" = "true" && set -x

if test -z "${CI_COMMIT_REF_NAME}"
then
    CI_PROJECT_DIR="$( cd "$(dirname "${0}")/.." || exit 97 ; pwd )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

banner "Cleaning up after failure"
#
# The functions below should be defined in the vendor_tools.lib.sh scripts
#
echo "getting images for: ${FOUNDATION_REGISTRY}"
images="$(_getDockerRepoNames)"
for _image in ${images:5}
do
    echo "  getting tags for image: ${_image}"
    tags="$(_getDockerTagsForRepo "${_image}" "${ciTag}")"
    for tag in ${tags}
    do
        echo "    untagging image tag: ${tag}"
        _untagDockerImage "${_image}" "${tag}"
    done
    digests=_getUntaggedImageDigests "${_image}"
    for digest in ${digests}
    do
        echo "    deleting image digest: ${digest}"
        _deleteImageDigest "${_image}" "${digest}"
    done
done

exit 0