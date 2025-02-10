#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

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
    # using heartbeat for continuation rather than a fixed timeout
    # fixed timeout ${ADMIN_WAITFOR_TIMEOUT} is a hard backstop for a startup that might hang
    # --retry-connrefused is necessary to use that failure as a retry condition (otherwise, the command fails the first attempt with exit code 7)
    # --retry default value is 0, but this parameter is required to use --retry-delay & --retry-max-time
    # with --retry at 9999, the actual limiting factor for retries is the ADMIN_WAITFOR_TIMEOUT variable
    curl --retry-connrefused --retry 9999 --retry-delay 5 --retry-max-time "${ADMIN_WAITFOR_TIMEOUT}" -sS -k -o /dev/null "https://127.0.0.1:${PF_ADMIN_PORT}/pf/heartbeat.ping"

    # check output of the curl command & act accordingly
    if test ${?} -ne 0; then
        echo "PingFederate did not respond to the heartbeat before ADMIN_WAITFOR_TIMEOUT=${ADMIN_WAITFOR_TIMEOUT} seconds elapsed"
        exit 1
    else
        echo "PingFederate is up"
    fi

    run_hook "81-after-start-process.sh"
    test ${?} -ne 0 && kill 1

    # everything was successful, pf is ready.
    touch /tmp/ready
fi
exit 0
