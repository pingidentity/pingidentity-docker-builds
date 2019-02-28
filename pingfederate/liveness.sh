#!/usr/bin/env sh
curl -ss -o /dev/null -k https://localhost:9031/pf/heartbeat.ping
if test ${?} -ne 0 ; then
    # the health check must return 0 for healthy, 1 otherwise
    # but not any other code so we catch the curl return code and
    # change any non-zero code to 1
    # https://docs.docker.com/engine/reference/builder/#healthcheck
    exit 1
fi