#!/usr/bin/env bash
# Copyright © 2026 Ping Identity Corporation

#
# Ping Identity DevOps - CI scripts
#
# aws utilities
#

# get all resources for repo starting with docker-builds
_getDockerRepoNames() {
    aws ecr describe-repositories | jq -r '.repositories[]|if (.repositoryName|startswith("docker-builds")) then .repositoryName else "" end'
}

# get all the tags for an image
_getDockerTagsForRepo() {
    aws ecr list-images --repository-name "${1}" | jq -r ".imageIds[]|select(.imageTag == \"${2}\")|.imageTag"
}

# untag an image
_untagDockerImage() {
    aws ecr batch-delete-image \
        --repository-name "${1}" \
        --image-ids imageTag="${2}"
}

# get all digest for untagged images
_getUntaggedImageDigests() {
    aws ecr list-images --repository-name "${1}" | jq -r '.imageIds[]|select(.imageTag == null)|.imageDigest'
}

# delete digest for an image
_deleteImageDigest() {
    aws ecr batch-delete-image \
        --repository-name "${1}" \
        --image-ids imageDigest="${2}"
}

# create access to the pipelineRepository
#
# Create a new secret for access to the pipeline's build registry specified in $PIPELINE_BUILD_REGISTRY.
# In order for the nodes to pull images from this registry, they have to have the credentials.
# Provide this information by creating a dockercfg secret and attaching it to the default
# service account
_createPipelineRepoAccess() {
    _ns="${1}"

    test -z "${_ns}" && echo_red "Namespace required to createPipelineRepoAccess" && exit 1

    # Create secret for dockerhub credentials to avoid rate limiting
    DOCKER_SECRET_NAME="dockerhub-config"
    export DOCKER_SECRET_NAME

    kubectl create secret docker-registry "${DOCKER_SECRET_NAME}" \
        --docker-server=https://index.docker.io/v1/ \
        --docker-username="${DOCKER_USERNAME}" \
        --docker-password="${DOCKER_ACCESS_TOKEN}" \
        --namespace="${_ns}"

    # Create secret for AWS ECR registry
    ECR_SECRET_NAME="aws-ecr-registry"
    export ECR_SECRET_NAME

    # AWS Version 2.x
    _awsToken="$(aws ecr get-login-password --region "${AWS_REGION}")"

    kubectl create secret docker-registry "${ECR_SECRET_NAME}" \
        --docker-server="https://${PIPELINE_BUILD_REGISTRY}" \
        --docker-username=AWS \
        --docker-password="${_awsToken}" \
        --namespace "${_ns}"

    kubectl patch serviceaccount default \
        --namespace "${_ns}" -p '{"imagePullSecrets":[{"name":"'${DOCKER_SECRET_NAME}'"},{"name":"'${ECR_SECRET_NAME}'"}]}'

    kubectl describe secret "${DOCKER_SECRET_NAME}" --namespace "${_ns}"
    kubectl describe secret "${ECR_SECRET_NAME}" --namespace "${_ns}"
    kubectl get serviceaccount default -o=yaml --namespace "${_ns}"
}

# use AWS credentials/config if available
requirePipelineVar AWS_SHARED_CREDENTIALS_FILE
requirePipelineVar AWS_CONFIG_FILE
requirePipelineVar PIPELINE_BUILD_REGISTRY

AWS_ACCOUNT_ID="$(echo "${PIPELINE_BUILD_REGISTRY}" | cut -d. -f1)"
AWS_REGION="$(echo "${PIPELINE_BUILD_REGISTRY}" | cut -d. -f4)"

export AWS_ACCOUNT_ID AWS_REGION

echo "Using AWS Shared Credential File '${AWS_SHARED_CREDENTIALS_FILE}'"
echo "Using AWS Shared Config File '${AWS_CONFIG_FILE}'"
echo "Using AWS Pipeline Build Registry '${PIPELINE_BUILD_REGISTRY}'"
