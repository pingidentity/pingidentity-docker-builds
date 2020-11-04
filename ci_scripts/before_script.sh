#!/usr/bin/env sh
set -xe
echo "hello from before script"

requirePipelineVar ()
{
    _pipelineVar="${1}"

    if test -z "${_pipelineVar}" ; then
        echo_red "${_pipelineVar} variable missing. Needs to be defined/created (i.e. ci/cd pipeline variable)"
        exit 1
    fi
}

pwd
env | sort
echo $USER
type jq
type python
python --version
type aws
aws --version
type az
az --version
type docker
docker info
type docker-compose
docker-compose version
type envsubst
envsubst --version
type gcloud
gcloud --version
type git
git --version

#
# perform a docker login to docker hub.  This is required to properly authenticate and
# sign images with docker as well as avoid rate limiting from Dockers new policies.
#
echo "Logging into docker hub..."
requirePipelineVar DOCKER_USERNAME
requirePipelineVar DOCKER_PASSWORD
export DOCKER_CONFIG_HUB_DIR="/root/.docker-hub"
mkdir -p "${DOCKER_CONFIG_HUB_DIR}"

#
# login to docker.io using the default config.json
#
docker --config "${DOCKER_CONFIG_HUB_DIR}" login --username "${DOCKER_USERNAME}" --password "${DOCKER_PASSWORD}"