#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is used to import any configurations that are
#- needed after PingAccess starts

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

if test -z "${OPERATIONAL_MODE}" || test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE" || test "${OPERATIONAL_MODE}" = "STANDALONE" ; then
  echo "INFO: waiting for PingAccess to start before importing configuration"
  wait-for localhost:9000 -t 200 --  "${HOOKS_DIR}/81-after-start-process.sh"
fi

if test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"  ; then
  echo "Bringing eth0 back up..."
  ip link set eth0 up
fi