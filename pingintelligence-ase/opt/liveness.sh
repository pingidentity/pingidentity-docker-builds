#!/usr/bin/env sh
#
# Ping Identity DevOps - Ping Intelligence Liveness Check
#
${VERBOSE} && set -x
result=$( "${SERVER_ROOT_DIR}/lib/controller" "${SERVER_ROOT_DIR}" api ping )
test ${?} -eq 0 && test "${result}" = "pong"