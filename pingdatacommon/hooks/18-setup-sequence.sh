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

    # apply the tools properties for convenience
    run_hook "185-apply-tools-properties.sh"

    # install custom extension provided
    run_hook "186-install-extensions.sh"

    # apply custom configuration provided
    run_hook "188-apply-configuration.sh"
  fi