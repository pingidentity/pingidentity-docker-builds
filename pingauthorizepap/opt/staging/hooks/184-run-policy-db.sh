#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

#
# The PAP introduced a new tool, policy-db in 9.2.0.0-GA. It upgrades a PostgreSQL policy
# database using the values in configuration.yml when the PING_POLICY_DB_SYNC environment
# variable is present. Because it performs an upgrade, it must be run regardless of whether
# this is a pristine container or is restarting. However, it reads the values within
# the configuration.yml, and therefore must be run after setup. The PING_POLICY_DB_SYNC
# environment variable is specific to the pingauthorizepap container and not
# recognized by the application. However, the --no-prompt option requires the presence
# of PING_DB_ADMIN_USERNAME and PING_DB_ADMIN_PASSWORD. Those variables are validated
# by the application.
#
if [ -x "${SERVER_ROOT_DIR}"/bin/policy-db ] && [ "true" = "${PING_POLICY_DB_SYNC}" ]; then
    "${SERVER_ROOT_DIR}"/bin/policy-db --no-prompt
fi
