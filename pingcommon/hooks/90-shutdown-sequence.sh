#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script may be implemented to gracefully shutdown the container
#- >Note: this is most useful in Kubernetes but can be called arbitrarily by
#- by control/config frameworks

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"
