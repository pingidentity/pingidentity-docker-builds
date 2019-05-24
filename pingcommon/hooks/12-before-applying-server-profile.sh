#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
# This script is called after the product bits have been copied over to the runtime location
# and before the remote server profile gets applied on to the staging area
#
# if the remote server profile is to be layered over a local sever profile provided via the
# ${IN_DIR} volume mount, you could use this hook to manipulate the local server profile in
# the staging area to avoid certain file from being overridden for example

# shellcheck source=../lib.sh
. "${BASE}/lib.sh"
