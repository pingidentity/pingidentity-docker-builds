#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=./pingintelligence.lib.sh
. "${HOOKS_DIR}/pingintelligence.lib.sh"

pi_obfuscate_keys
test ${?} -ne 0 && echo_red "Error obfuscating keys" && exit 50

exit 0