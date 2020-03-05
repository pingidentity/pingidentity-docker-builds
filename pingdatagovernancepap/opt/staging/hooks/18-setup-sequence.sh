#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- Quarterbacks all the scripts associated with the setup of a
#- PingData product
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

 if test ! -f "${SERVER_ROOT_DIR}/config/server.uuid" ; then

    # setup the instance given all the provided data
    run_hook "183-run-setup.sh"
  fi