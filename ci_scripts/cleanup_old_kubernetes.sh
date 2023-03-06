#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# This script will cleanup and delete old Kubernetes namespaces
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

# Set how long till deletion
one_days_ago=$(($(date +%s) - (24 * 60 * 60)))

# Delete all namespaces with dbt-
K8S_NS_PREFIX="dbt-"

banner "Cleaning any kubernetes namespaces starting with '${K8S_NS_PREFIX}'"

# Get list of all ns to be deleted
_ns_candidates_to_delete=$(kubectl get ns -o=json | jq -r ".items[] | select(.metadata.name | startswith(\"${K8S_NS_PREFIX}\")) | .metadata.name")

banner "Deleting Namespaces ${_ns_candidates_to_delete}"

for _ns in ${_ns_candidates_to_delete}; do
    # get the creation date of the ns and convert it into epoch
    ns_date=$(kubectl get ns "${_ns}" -o=json | jq -r ".metadata.creationTimestamp | strptime(\"%Y-%m-%dT%H:%M:%SZ\")|mktime")
    if test ${one_days_ago} -gt "${ns_date}"; then
        banner "Deleting namespace ${_ns}"
        kubectl delete ns --force=true --grace-period=0 "${_ns}"
    fi
done

banner "kubectl get ns"
kubectl get ns

exit 0
