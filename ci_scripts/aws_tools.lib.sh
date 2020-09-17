#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# aws utilities
#

# get all resources for repo starting with docker-builds
_getDockerRepoNames ()
{
    aws ecr describe-repositories | jq -r '.repositories[]|if (.repositoryName|startswith("docker-builds")) then .repositoryName else "" end'
}

# get all the tags for an image
_getDockerTagsForRepo ()
{
    aws ecr list-images --repository-name "${1}" | jq -r ".imageIds[]|select(.imageTag == \"${2}\")|.imageTag"
}

# untag an image
_untagDockerImage ()
{
    aws ecr batch-delete-image \
              --repository-name "${1}" \
              --image-ids imageTag="${2}"
}

# get all digest for untagged images
_getUntaggedImageDigests ()
{
    aws ecr list-images --repository-name "${1}" | jq -r '.imageIds[]|select(.imageTag == null)|.imageDigest'
}

# delete digest fr an image
_deleteImageDigest ()
{
    aws ecr batch-delete-image \
        --repository-name "${1}" \
        --image-ids imageDigest="${2}"
}

# use AWS credentials/config if available
requirePipelineVar AWS_SHARED_CREDENTIALS_FILE
requirePipelineVar AWS_CONFIG_FILE

echo "Using AWS Shared Credential File '${AWS_SHARED_CREDENTIALS_FILE}'"
echo "Using AWS Shared Config File '${AWS_CONFIG_FILE}'"
