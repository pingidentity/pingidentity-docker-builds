#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is used to import any configurations that are
#- needed after PingAccess starts

# shellcheck disable=SC1090
. "${HOOKS_DIR}/pingcommon.lib.sh"

#change initial Password
if test -z "${OPERATIONAL_MODE}" || test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"  ; then
  wait-for localhost:9000 -t 200 --  "${HOOKS_DIR}/81-after-start-process.sh"
fi