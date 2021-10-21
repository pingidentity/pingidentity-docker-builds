#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# azure utilities
#

# get all versions (from versions.json) for a product to build
_getDockerRepoNames() {
    echo "not implemented"
}

# get all the tags for an image
_getDockerTagsForRepo() {
    echo "not implemented"
}

# untag an image
_untagDockerImage() {
    echo "not implemented"
}

# get all digest for untagged images
_getUntaggedImageDigests() {
    echo "not implemented"
}

# delete digest for an image
_deleteImageDigest() {
    echo "not implemented"
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

# use az credentials/config if available
# requirePipelineFile
# requirePipelineVar

echo_red "Azure Tools not implemented"

exit 1
