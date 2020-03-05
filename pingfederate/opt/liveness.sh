#!/usr/bin/env sh
URL="https://localhost:${PF_ENGINE_PORT}/pf/heartbeat.ping"
test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE" && URL="https://localhost:${PF_ADMIN_PORT}/pingfederate/app"
curl -sSk -o /dev/null "${URL}"
if test ${?} -ne 0 ; 
then
    # the health check must return 0 for healthy, 1 otherwise
    # but not any other code so we catch the curl return code and
    # change any non-zero code to 1
    # https://docs.docker.com/engine/reference/builder/#healthcheck
    exit 1
fi