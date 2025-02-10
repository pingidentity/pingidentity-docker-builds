#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# Toggle on debug logging if DEBUG=true is set
start_debug_logging
## attempt to accept license, works if new server, fails if admin exists.
_acceptLicenseAgreement=$(
    curl \
        --insecure \
        --silent \
        --request PUT \
        --write-out '%{http_code}' \
        --output /tmp/license.acceptance \
        --header "X-XSRF-Header: PingFederate" \
        --header 'Content-Type: application/json' \
        --data '{"accepted":true}' \
        "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/license/agreement" \
        2> /dev/null
)
# Toggle off debug logging
stop_debug_logging

case "${_acceptLicenseAgreement}" in
    200)
        # This is a new PingFederate instance, then create admin user.
        echo "INFO: new server found, must create admin"

        # Make sure PING_IDENTITY_PASSWORD is defined
        test -z "${PING_IDENTITY_PASSWORD}" && container_failure 83 "ERROR: PING_IDENTITY_PASSWORD is not defined. Could not create administrator user."

        # Toggle on debug logging if DEBUG=true is set
        start_debug_logging
        # Set script vars
        # TODO Remove if-else logic when PF 12.1 is no longer built
        if test "$(isImageVersionGtEq 12.2.0)" -eq "0"; then
            admin_roles='["ADMINISTRATOR","USER_ADMINISTRATOR","CRYPTO_ADMINISTRATOR","EXPRESSION_ADMINISTRATOR","DATA_COLLECTION_ADMINISTRATOR"]'
        else
            admin_roles='["ADMINISTRATOR","USER_ADMINISTRATOR","CRYPTO_ADMINISTRATOR","EXPRESSION_ADMINISTRATOR"]'
        fi
        _createAdminUser=$(
            curl \
                --insecure \
                --silent \
                --write-out '%{http_code}' \
                --output /tmp/create.admin \
                --request POST \
                --header "X-XSRF-Header: PingFederate" \
                --header 'Content-Type: application/json' \
                --data '{"username": "administrator", "password": "'"${PING_IDENTITY_PASSWORD}"'",
          "description": "Initial administrator user.", 
          "auditor": false,"active": true, 
          "roles": '"${admin_roles}"' }' \
                "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/administrativeAccounts" \
                2> /dev/null
        )
        # Toggle off debug logging
        stop_debug_logging
        if test "${_createAdminUser}" != "200"; then
            echo_red "$(jq -r . /tmp/create.admin)"
            echo_red "error attempting to create admin"
            exit 83
        fi
        ;;
    401)
        echo "INFO: Found existing admin PingFederate instance. Skipping creation of new admin user."
        ;;
    *)
        echo_red "$(jq -r . /tmp/license.acceptance)"
        echo_red "License Agreement Failed"
        exit 83
        ;;
esac
