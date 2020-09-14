#!/usr/bin/env sh
set -xe
echo "hello from before script"

pwd
env
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