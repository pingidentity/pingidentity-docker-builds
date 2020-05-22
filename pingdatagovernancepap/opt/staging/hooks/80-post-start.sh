#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is used to import any configurations that are
#- needed after PingDataGovernance-PAP starts

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

echo "INFO: waiting for PingDataGovernance-PAP to start before importing configuration"
# shellcheck disable=SC2086
wait-for localhost:${HTTPS_PORT} -t 200 --  echo "pap running"

run_hook 81-install-policies.sh