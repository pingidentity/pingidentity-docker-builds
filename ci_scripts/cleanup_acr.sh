#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# This script cleans up the Azure Container Registry (acr)
#
test -n "${VERBOSE}" && set -x

if test -z "${CI_COMMIT_REF_NAME}"
then
    CI_PROJECT_DIR="$( cd "$( dirname "${0}" )/.." || exit 97 ; pwd )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

while read -r _registry
do
    for _product in apache-jmeter ldap-sdk-tools pingaccess pingcentral pingdataconsole pingdatagovernance pingdatagovernancepap pingdatasync pingdirectory pingdirectoryproxy pingdownloader pingfederate pingtoolkit
    do
        while read -r _sha
        do
            az acr repository delete --name "${_registry}" --image "${_product}@${_sha}" --yes
        done < <( az acr repository show-manifests --name "${_registry}" --repository "${_product}" --query "[?tags[0]==null].digest" -o tsv )
    done  # < <( find "${CI_PROJECT_DIR}" -name versions.json )
done < <( jq -r '.registries[]|select(.provider=="azure")|.registry' "${CI_PROJECT_DIR}/registries.json" )
exit 0