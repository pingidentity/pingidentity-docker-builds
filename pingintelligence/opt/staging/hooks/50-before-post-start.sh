#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=./pingintelligence.lib.sh
. "${HOOKS_DIR}/pingintelligence.lib.sh"

pi_obfuscate_keys
if test ${?} -ne 0; then
    echo_red "Error obfuscating keys"
    exit 50
fi
