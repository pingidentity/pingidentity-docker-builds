#!/usr/bin/env sh
${VERBOSE} && set -x

# shellcheck source=lib.sh
. "${BASE}/lib.sh"

echo "Restarting container"

# if this hook is provided it can be executed early on
run_if present "${HOOKS_DIR}/21-update-server-profile.sh"
die_on_error 21 "Issue encountered while updating server profile"
