#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

if test -d "${STAGING_DIR}/dsconfig" ; then
    echo_red "Configs in '${STAGING_DIR}/dsconfig' are deprecated."
    echo_red "They should be placed in '${PD_PROFILE}/dsconfig' going foward."

fi