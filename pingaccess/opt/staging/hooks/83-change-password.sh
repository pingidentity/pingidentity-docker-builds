#!/usr/bin/env sh
# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

pingaccess_private_port=${PA_ADMIN_PORT}
test -n "${PA_ADMIN_PRIVATE_PORT_HTTPS}" && pingaccess_private_port=${PA_ADMIN_PRIVATE_PORT_HTTPS}

pingaccess_api_out=$(mktemp)

# Agree to the EULA for the administrator
accept_administrator_eula() {
    test -z "${1}" && container_failure 83 "ERROR: The function accept_administrator_eula requires a password."
    echo "INFO: Accepting end user license agreement. PING_IDENTITY_ACCEPT_EULA = ${PING_IDENTITY_ACCEPT_EULA}"
    https_result_code=$(
        curl \
            --insecure \
            --silent \
            --request PUT \
            --write-out '%{http_code}' \
            --user "${ROOT_USER}:${1}" \
            --output "${pingaccess_api_out}" \
            --header "X-Xsrf-Header: PingAccess" \
            --data '{ "email": null, "slaAccepted": true, "firstLogin": false, "showTutorial": false,"username": "'"${ROOT_USER}"'"}' \
            "https://localhost:${pingaccess_private_port}/pa-admin-api/v3/users/1" \
            2> /dev/null
    )

    if test "${https_result_code}" != "200"; then
        cat "${pingaccess_api_out}"
        container_failure 83 "ERROR: Could not accept End User License Agreement"
    fi
}

# Make an attempt to authenticate with the user-provided administrator password
https_result_code=$(
    curl \
        --insecure \
        --silent \
        --write-out '%{http_code}' \
        --output "${pingaccess_api_out}" \
        --request GET \
        --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
        -H "X-Xsrf-Header: PingAccess" \
        "https://localhost:${pingaccess_private_port}/pa-admin-api/v3/users/1" \
        2> /dev/null
)

# Check to see if the user-provided administrator password authenticated correctly.
# If so, make sure the EULA is accepted.
if test "${https_result_code}" = "200"; then
    slaAccepted="$(jq -r '.slaAccepted' "${pingaccess_api_out}")"
    if test "${slaAccepted}" != "true"; then
        # Accepted the EULA
        accept_administrator_eula "${PING_IDENTITY_PASSWORD}"
    fi
else # Else attempt to authenticate with the default initial administrator password
    https_result_code=$(
        curl \
            --insecure \
            --silent \
            --write-out '%{http_code}' \
            --output "${pingaccess_api_out}" \
            --request GET \
            --user "${ROOT_USER}:${PA_ADMIN_PASSWORD_INITIAL}" \
            --header "X-Xsrf-Header: PingAccess" \
            "https://localhost:${pingaccess_private_port}/pa-admin-api/v3/users/1" \
            2> /dev/null
    )
    # Check to see if the default initial administrator password authenticated correctly.
    # If so, accept the EULA and change the administrator password.
    if test "${https_result_code}" = "200"; then
        # Accepted the EULA
        accept_administrator_eula "${PA_ADMIN_PASSWORD_INITIAL}"

        # Change the administrator password
        if test -n "${PING_IDENTITY_PASSWORD}"; then
            echo "INFO: Changing administrator password"
            https_result_code=$(
                curl \
                    --insecure \
                    --silent \
                    --write-out '%{http_code}' \
                    --output "${pingaccess_api_out}" \
                    --request PUT \
                    --user "${ROOT_USER}:${PA_ADMIN_PASSWORD_INITIAL}" \
                    --header "X-Xsrf-Header: PingAccess" \
                    --data '{"currentPassword": "'"${PA_ADMIN_PASSWORD_INITIAL}"'","newPassword": "'"${PING_IDENTITY_PASSWORD}"'"}' \
                    "https://localhost:${pingaccess_private_port}/pa-admin-api/v3/users/1/password" \
                    2> /dev/null
            )

            if test "${https_result_code}" != "200"; then
                cat "${pingaccess_api_out}"
                container_failure 83 "ERROR: Administrator password change not accepted"
            fi
        else
            container_failure 83 "ERROR: PING_IDENTITY_PASSWORD is not defined"
        fi
    else # Neither PING_IDENTITY_PASSWORD nor PA_ADMIN_PASSWORD_INITIAL authenticated. This is an error state.
        container_failure 83 "ERROR: No valid administrator password found - Check variables PING_IDENTITY_PASSWORD and PA_ADMIN_PASSWORD_INITIAL"
    fi
fi

rm -f "${pingaccess_api_out}"

exit 0
