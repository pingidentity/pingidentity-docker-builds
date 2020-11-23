#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is used to import any configurations that are
#- needed after PingDataGovernance-PAP starts

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdatacommon.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# shellcheck source=pingdatagovernancepap.lib.sh
test -f "${HOOKS_DIR}/pingdatagovernancepap.lib.sh" && . "${HOOKS_DIR}/pingdatagovernancepap.lib.sh"

# Do not load policies if the PAP was set up in OIDC mode
if use_oidc_mode ; then
  exit
fi

if is_version_ge "8.2.0.0-GA" ;
then
  _url=localhost:${PING_ADMIN_PORT:-8444}/healthcheck
else
  _url=localhost:${HTTPS_PORT}
fi
echo "INFO: waiting for PingDataGovernance-PAP to start before importing configuration"
# shellcheck disable=SC2086
wait-for ${_url} -t 200 --  echo "pap running"

run_hook 81-install-policies.sh
