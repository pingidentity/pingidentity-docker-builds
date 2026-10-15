#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook may be used to set the server if there is a setup procedure
#
#- >Note: The PingData (i.e. Directory, DataSync, PingAuthorize, DirectoryProxy)
#- products will all provide this

# shellcheck source=./pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"
