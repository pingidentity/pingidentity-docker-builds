#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook may be used to set the server if there is a setup procedure
# 
#- >Note: The PingData (i.e. Directory, DataSync, DataGovernance, DirectoryProxy) 
#- products will all provide this

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"
