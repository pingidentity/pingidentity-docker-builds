#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

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
    # setup the instance given all the provided data
    run_hook "183-run-setup.sh"
fi

run_hook "184-run-policy-db.sh"
