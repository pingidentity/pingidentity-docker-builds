#!/usr/bin/env sh
# Ping Identity DevOps - Docker Build Hooks
#
# Prints out variables and startup information when the server is started.
#
# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# warn about any UNSAFE_ or deprecated variables
print_variable_warnings

echo_header "Ping Federate Info"
echo_vars PF_ENGINE_PUBLIC_HOSTNAME PF_ENGINE_PUBLIC_PORT PF_DELEGATOR_CLIENTID

echo_header "Ping Directory Info"
echo_vars PD_ENGINE_PUBLIC_HOSTNAME PD_ENGINE_PUBLIC_PORT

echo_header "Ping Delegator Info"
echo_vars PD_DELEGATOR_TIMEOUT_LENGTH_MINS PD_DELEGATOR_HEADER_BAR_LOGO PD_DELEGATOR_DADMIN_API_NAMESPACE PD_DELEGATOR_PROFILE_SCOPE_ENABLED
