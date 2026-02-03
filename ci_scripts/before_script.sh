#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

set -xe
echo "hello from before script"

pwd
env | sort
echo "${USER}"
type jq
type python
python --version
type aws
aws --version

#Uncomment these lines and update docker-builds-runner image if azure_tools.lib.sh is used in the pipeline. See $PIPELINE_BUILD_REGISTRY_VENDOR.
#type az
#az --version

type docker
docker info
type docker-compose
docker-compose version
type envsubst
envsubst --version
type kubectl
kubectl version --client=true

#Uncomment these lines and update docker-builds-runner image if google_tools.lib.sh is used in the pipeline. See $PIPELINE_BUILD_REGISTRY_VENDOR.
#type gcloud
#gcloud --version

type git
git --version
type notary
notary version

# Do not output Vault Secrets or token to logs
set +xe

#Retreive the vault token to authenticate for vault secrets
VAULT_TOKEN="$(vault write -field=token auth/jwt_v2/login role=pingdevops jwt="${VAULT_ID_TOKEN}")"
test -z "${VAULT_TOKEN}" && VAULT_TOKEN="$(vault write -field=token auth/jwt_v2/login role=pingdevops-tag jwt="${VAULT_ID_TOKEN}")"
test -z "${VAULT_TOKEN}" && echo "Error: Vault token was not retrieved" && exit 1
export VAULT_TOKEN

#Retreive the vault secret
vault kv get -mount=pingdevops -field=Signing_Key_Base64 Base64_key > "${VAULT_SECRET_FILE}"
test $? -ne 0 && echo "Error: Failed to retrieve private docker keys from vault" && exit 1

return 0
