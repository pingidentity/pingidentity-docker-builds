#!/usr/bin/env bash
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - CI scripts
#
# azure utilities
#

# get all versions (from versions.json) for a product to build
# This file is not implemented in ci_tools.lib.sh. Disable shellcheck.
# shellcheck disable=SC2317
_getDockerRepoNames() {
    echo "not implemented"
}

# get all the tags for an image
# This file is not implemented in ci_tools.lib.sh. Disable shellcheck.
# shellcheck disable=SC2317
_getDockerTagsForRepo() {
    echo "not implemented"
}

# untag an image
# This file is not implemented in ci_tools.lib.sh. Disable shellcheck.
# shellcheck disable=SC2317
_untagDockerImage() {
    echo "not implemented"
}

# get all digest for untagged images
# This file is not implemented in ci_tools.lib.sh. Disable shellcheck.
# shellcheck disable=SC2317
_getUntaggedImageDigests() {
    echo "not implemented"
}

# delete digest for an image
# This file is not implemented in ci_tools.lib.sh. Disable shellcheck.
# shellcheck disable=SC2317
_deleteImageDigest() {
    echo "not implemented"
}

# create access to the pipelineRepository
#
# Create a new secret for access to the pipeline's build registry specified in $PIPELINE_BUILD_REGISTRY.
# In order for the nodes to pull images from this registry, they have to have the credentials.
# Provide this information by creating a dockercfg secret and attaching it to the default
# service account
# This file is not implemented in ci_tools.lib.sh. Disable shellcheck.
# shellcheck disable=SC2317
_createPipelineRepoAccess() {
    echo "not implemented"
}

# use az credentials/config if available
# requirePipelineFile
# requirePipelineVar

echo_red "Azure Tools not implemented"

exit 1
