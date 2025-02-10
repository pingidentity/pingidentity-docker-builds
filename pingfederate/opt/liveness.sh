#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

URL="https://127.0.0.1:${PF_ENGINE_PORT}/pf/heartbeat.ping"
if test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE" -o "${OPERATIONAL_MODE}" = "STANDALONE"; then
    if ! test -f /tmp/ready; then
        exit 1
    fi
    test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE" && URL="https://127.0.0.1:${PF_ADMIN_PORT}/pingfederate/app"
fi
curl -sSk -o /dev/null "${URL}"
if test ${?} -ne 0; then
    # the health check must return 0 for healthy, 1 otherwise
    # but not any other code so we catch the curl return code and
    # change any non-zero code to 1
    # https://docs.docker.com/engine/reference/builder/#healthcheck
    exit 1
fi
