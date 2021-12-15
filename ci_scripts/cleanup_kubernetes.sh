#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# This script will cleanup a docker environment
#
test "${VERBOSE}" = "true" && set -x

if test -z "${CI_COMMIT_REF_NAME}"; then
    CI_PROJECT_DIR="$(
        cd "$(dirname "${0}")/.." || exit 97
        pwd
    )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

# Delete all namespaces with dbt-branch-pipeline-id-*

K8S_NS_PREFIX="dbt-${CI_COMMIT_REF_SLUG:-$USER}-${CI_PIPELINE_ID}"

banner "Cleaning any kubernetes namespaces starting with '${K8S_NS_PREFIX}'"

_ns_candidates_to_delete=$(kubectl get ns -o=json | jq -r ".items[] | select(.metadata.name | startswith(\"${K8S_NS_PREFIX}\")) | .metadata.name")

banner "Deleting Namespaces ${_ns_candidates_to_delete}"

for _ns in ${_ns_candidates_to_delete}; do
    banner "Deleting namespace ${_ns}"

    kubectl delete ns --force=true --grace-period=0 "${_ns}"
done

banner "kubectl get ns"
kubectl get ns

exit 0
