#!/usr/bin/env sh
set -x

# shellcheck source=lib.sh
. "${BASE}/lib.sh"

deploy_server_bits ()
{
  test -d "${SERVER_ROOT_DIR}" || cp -af "${BASE}/server" "${SERVER_ROOT_DIR}"
}


echo "Initializing server for the first time"

# if this hook is provided it can be executed early on
run_if present "${HOOKS_DIR}/11-before-copying-bits.sh"

# lay down the bits to the runtime volume
deploy_server_bits

run_if present "${HOOKS_DIR}/12-before-applying-server-profile.sh"

run_if present "${HOOKS_DIR}/14-get-remote-server-profile.sh"

run_if present "${HOOKS_DIR}/16-apply-server-profile.sh"

# environment variables will be provided by the server profile
# shellcheck disable=SC1090
test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"

run_if present "${HOOKS_DIR}/18-setup-sequence.sh"
