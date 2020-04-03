#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is used to import any configurations that are
#- needed after PingDataGovernance-PAP starts

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

echo "INFO: waiting for PingDataGovernance-PAP to start before importing configuration"
wait-for localhost:${HTTPS_PORT} -t 200 --  echo "pap running"

run_hook 81-install-policies.sh