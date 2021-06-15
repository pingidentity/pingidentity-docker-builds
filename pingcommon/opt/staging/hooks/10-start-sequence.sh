#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
# Called when it has been determined that this is the first time the container has
# been run.
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=./pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

echo "Initializing server for the first time"

run_hook "17-check-license.sh"

run_hook "18-setup-sequence.sh"
