#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is called to determine the plan for the server as it starts up.
#

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# shellcheck source=./pingdirectory.lib.sh
. "${HOOKS_DIR}/pingdirectory.lib.sh"

test "${VERBOSE}" = "true" && set -x

buildRunPlan
