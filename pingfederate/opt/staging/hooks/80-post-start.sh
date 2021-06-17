#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is used to import any configurations that are
#- needed after PingFederate starts

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

if test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE" -o "${OPERATIONAL_MODE}" = "STANDALONE"; then
    echo "INFO: waiting for healthy admin before post-start.."

    # using 127.0.0.1 (rather than localhost) until nc (part of busybox) supports ipv4/ipv6
    wait-for "127.0.0.1:${PF_ADMIN_PORT}" -t 200
    test ${?} -ne 0 && kill 1
    "${HOOKS_DIR}/81-after-start-process.sh"
    test ${?} -ne 0 && kill 1

    # everything was successful, pf is ready.
    touch /tmp/ready
fi
exit 0
