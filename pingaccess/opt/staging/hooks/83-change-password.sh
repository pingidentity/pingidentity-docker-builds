#!/usr/bin/env sh
# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# attempt to authenticate with the expected initial administrator password
_pwCheckInitial=$( 
    curl \
        --insecure \
        --silent \
        --write-out '%{http_code}' \
        --output /dev/null \
        --request GET \
        --user "${ROOT_USER}:${PA_ADMIN_PASSWORD_INITIAL}" \
        --header "X-Xsrf-Header: PingAccess" \
        https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/users/1 \
        2>/dev/null
    )
# echo "${_pwCheckInitial}"
if test "${_pwCheckInitial}" != "200"
then
    die_on_error 83 "Bad password - check vars PING_IDENTITY_PASSWORD PA_ADMIN_PASSWORD_INITIAL" || exit ${?}
fi

# Quiesce the license acceptance screen
# TODO: we should handle the returned HTTP code and display a useful error if the PUT returns a message
_license_http_code=$( 
    curl \
        --insecure \
        --silent \
        --request PUT \
        --write-out '%{http_code}' \
        --user "${ROOT_USER}:${PA_ADMIN_PASSWORD_INITIAL}" \
        --output /tmp/license.acceptance \
        --header "X-Xsrf-Header: PingAccess" \
        --data '{ "email": null, "slaAccepted": true, "firstLogin": false, "showTutorial": false,"username": "'"${ROOT_USER}"'"}' \
        https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/users/1 \
        2>/dev/null
    )
if test "${_license_http_code}" != "200" 
then
    die_on_error 83 "Could not accept license" || exit ${?}
fi

echo "INFO: changing admin password"
PASSWORD=${PING_IDENTITY_PASSWORD:-${PA_ADMIN_PASSWORD:-${INITIAL_ADMIN_PASSWORD}}}
_pwChange=$(
    curl \
        --insecure \
        --silent \
        --write-out '%{http_code}' \
        --output /dev/null \
        --request PUT \
        --user "${ROOT_USER}:${PA_ADMIN_PASSWORD_INITIAL}" \
        --header "X-Xsrf-Header: PingAccess" \
        --data '{"currentPassword": "'"${PA_ADMIN_PASSWORD_INITIAL}"'","newPassword": "'"${PASSWORD}"'"}' \
        https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/users/1/password \
        2>/dev/null
    )

if test "${_pwChange}" != "200"
then
    die_on_error 83 "Password not accepted" || exit ${?}
fi