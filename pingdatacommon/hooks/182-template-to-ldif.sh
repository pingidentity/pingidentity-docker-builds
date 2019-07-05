#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook will import data into the PingDirectory if there are data files
#- included in the server profile data directory.
#-
#- If a .template file is provided, then makeldif will be run to create the .ldif
#- file to be imported.
#-
#- To be implemented by the downstream product (i.e. pingdirectory)
#

${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"
