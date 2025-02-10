#!/usr/bin/env bash
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - CI scripts
#
# gcloud utilities
#

# get all versions (from versions.json) for a product to build
_getDockerRepoNames() {
    gcloud container images list --repository="${FOUNDATION_REGISTRY}"
}

# get all the tags for an image
_getDockerTagsForRepo() {
    gcloud container images list-tags "${1}" --format="value(tags)" --filter=TAGS:"${2}" | sed -e 's/,/ /g'
}

# untag an image
_untagDockerImage() {
    gcloud container images untag "${1}:${2}" --quiet
}

# get all the tags for an image
_getUntaggedImageDigests() {
    gcloud container images list-tags "${1}" --filter='-tags:*' --format='get(digest)' --limit=1000
}

# delete digest for an image
_deleteImageDigest() {
    gcloud container images delete "${1}@${2}" --quiet
}

# create access to the pipelineRepository
#
# Create a new secret for access to the pipeline's build registry specified in $PIPELINE_BUILD_REGISTRY.
# In order for the nodes to pull images from this registry, they have to have the credentials.
# Provide this information by creating a dockercfg secret and attaching it to the default
# service account
_createPipelineRepoAccess() {
    echo "not implemented"
}

# use gcloud credentials/config if available
requirePipelineFile GCLOUD_KEY_JSON_FILE
requirePipelineVar GCLOUD_ACCOUNT

echo "Using gcloud key file '${GCLOUD_KEY_JSON_FILE}'"

gcloud auth activate-service-account "${GCLOUD_ACCOUNT}" \
    --key-file="${GCLOUD_KEY_JSON_FILE}" \
    --quiet
