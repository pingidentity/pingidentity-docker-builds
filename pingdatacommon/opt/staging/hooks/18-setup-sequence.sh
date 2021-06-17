#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- Quarterbacks all the scripts associated with the setup of a
#- PingData product
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

if test ! -f "${SERVER_ROOT_DIR}/config/server.uuid"; then

    # install custom extension provided
    run_hook "181-install-extensions.sh"

    # allow products to run any pre-setup commands
    run_hook "182-pre-setup.sh"

    # setup the instance given all the provided data
    run_hook "183-run-setup.sh"

    # apply the tools properties for convenience
    run_hook "185-apply-tools-properties.sh"

    # apply custom configuration provided
    run_hook "188-apply-configuration.sh"
fi
