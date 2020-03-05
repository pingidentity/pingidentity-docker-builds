#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook can be called to run the actual setup command line tool.
#-
#- It should be overridden by all the PingData product images.
#-

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

container_failure 183 "${0} must be implemented in PingData Docker Build Hooks"