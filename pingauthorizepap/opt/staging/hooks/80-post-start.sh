#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is used to import any configurations that are
#- needed after PingAuthorize Policy Editor starts

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# shellcheck source=./pingauthorizepap.lib.sh
test -f "${HOOKS_DIR}/pingauthorizepap.lib.sh" && . "${HOOKS_DIR}/pingauthorizepap.lib.sh"

# Do not load policies if the Policy Editor was set up in OIDC mode
if use_oidc_mode; then
    exit
fi

echo "INFO: waiting for PingAuthorize Policy Editor to start before importing configuration"

# The 8.2.0.0-GA release exposes a new healthcheck endpoint using a self-signed certificate,
# which requires something other than wait-for to test. Try 5 times to request it.
_tries=5
while test ${_tries} -gt 0 &&
    ! _curl --insecure "https://127.0.0.1:${PING_ADMIN_PORT:-8444}/healthcheck" 2> /dev/null; do
    sleep 3
    _tries=$((_tries - 1))
done

run_hook 81-install-policies.sh
