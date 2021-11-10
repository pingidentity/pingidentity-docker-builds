#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is used to import any configurations that are
#- needed after PingAccess starts

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

if test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE" || test "${OPERATIONAL_MODE}" = "STANDALONE"; then
    echo "INFO: waiting for PingAccess to start before importing configuration"

    # using 127.0.0.1 (rather than localhost) until nc (part ob busybox) supports ipv4/ipv6
    wait-for "127.0.0.1:${PA_ADMIN_PORT}" -t 200 -- echo PingAccess is up
    "${HOOKS_DIR}/81-after-start-process.sh"
    test ${?} -ne 0 && kill 1

    # everything was successful, pa is ready.
    touch /tmp/ready
fi
