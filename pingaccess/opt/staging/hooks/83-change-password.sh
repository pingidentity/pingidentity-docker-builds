#!/usr/bin/env sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

_pwCheckInitial=$( curl -ks --write-out %{http_code} --output /dev/null -X GET \
  -u administrator:${PA_ADMIN_PASSWORD_INITIAL} -H "X-Xsrf-Header: PingAccess" \
  https://localhost:9000/pa-admin-api/v3/users/1 )
# echo "${_pwCheckInitial}"
test ! "${_pwCheckInitial}" -gt 200
die_on_error 83 "Bad password - check vars PA_ADMIN_PASSWORD PA_ADMIN_PASSWORD_INITIAL" || exit ${?}

curl -ks -X PUT -u Administrator:"${PA_ADMIN_PASSWORD_INITIAL}" -H "X-Xsrf-Header: PingAccess" -d '{ "email": null,
    "slaAccepted": true,
    "firstLogin": false,
    "showTutorial": false,
    "username": "Administrator"
}' https://localhost:9000/pa-admin-api/v3/users/1 > /dev/null

echo "INFO: changing admin password"
_pwChange=$(curl -ks --write-out %{http_code} --output /dev/null -X PUT -u Administrator:"${PA_ADMIN_PASSWORD_INITIAL}" -H "X-Xsrf-Header: PingAccess" -d '{
  "currentPassword": "'"${PA_ADMIN_PASSWORD_INITIAL}"'",
  "newPassword": "'"${PA_ADMIN_PASSWORD}"'"
}' https://localhost:9000/pa-admin-api/v3/users/1/password)
test ! "${_pwChange}" -gt 200
die_on_error 83 "Password not accepted" || exit ${?}