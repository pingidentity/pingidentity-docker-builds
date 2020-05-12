#!/usr/bin/env sh
# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

test -n "${INITIAL_ADMIN_PASSWORD}" && echo_yellow "WARNING: INITIAL_ADMIN_PASSWORD is deprecated, use PING_IDENTITY_PASSWORD"
test -n "${PA_ADMIN_PASSWORD}" && echo_yellow "WARNING: PA_ADMIN_PASSWORD is deprecated, use PING_IDENTITY_PASSWORD"
PASSWORD=${PING_IDENTITY_PASSWORD:-${PA_ADMIN_PASSWORD:-INITIAL_ADMIN_PASSWORD}}

# Make an attempt to authenticate with the provided expected administrator password
_pwCheck=$( 
    curl \
        --insecure \
        --silent \
        --write-out '%{http_code}' \
        --output /dev/null \
        --request GET \
        --user "${ROOT_USER}:${PASSWORD}" \
        -H "X-Xsrf-Header: PingAccess" \
        https://localhost:9000/pa-admin-api/v3/users/1 \
        2>/dev/null
    )

# if not successful, attempt to update the password using the default
if test "${_pwCheck}" -ne 200
then
    run_hook "83-change-password.sh"
fi

echo "Checking for data.json to import.."
if test -f "${STAGING_DIR}/instance/data/data.json"
then
    if test -f "${STAGING_DIR}/instance/conf/pa.jwk"
    then
        if test -f "${STAGING_DIR}/instance/data/PingAccess.mv.db" 
        then
            echo "INFO: file named /instance/data/data.json found and will overwrite /instance/data/PingAccess.mv.db"
        else
            echo "INFO: file named /instance/data/data.json found"
        fi
        run_hook "85-import-configuration.sh"
    else 
        echo "WARNING: instance/data/data.json found, but no /instance/conf/pa.jwk found"
        echo "WARNING: skipping import."
    fi
else
    echo "INFO: No file named /instance/data/data.json found, skipping import."
fi