#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This will short circut the upper level pingcommon
#-

${VERBOSE} && set -x

# shellcheck source=../pingcommon/lib.sh
. "${BASE}/lib.sh"
