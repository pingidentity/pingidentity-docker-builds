#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

PAP_ADMIN=${PAP_ADMIN:-admin}

echo "Checking PAP system status..."
while true; do
    status=$(curl -H "x-user-id: ${PAP_ADMIN}" -k https://localhost:${HTTPS_PORT}/api/system/status 2>/dev/null | jq -r '.status')
    if test "${status}" = "RUNNING" ; then
        echo "PAP is ready"
        break
    else
        echo "PAP is not ready, waiting to try again..."
        sleep 3
    fi
done

if test -d "${STAGING_DIR}/policies" ; then
    for policyFileName in $( find "${STAGING_DIR}/policies/" -iname \*.SNAPSHOT 2>/dev/null | sort | uniq ) ; do
        policyName=$(basename ${policyFileName})
        echo "Importing policy snapshot: ${policyName}"
        snapshotId=$(curl -H "x-user-id: ${PAP_ADMIN}" -k -d @${policyFileName} https://localhost:${HTTPS_PORT}/api/snapshot/${policyName}/import | jq -r '.id')

        echo "Created Snapshot ID: ${snapshotId}"

        if test "${snapshotId}" = null; then
            container_failure "81" "Policy '${policyName}' could not be created"
        fi
    done
fi