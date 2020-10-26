#!/usr/bin/env sh
# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

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
      2>/dev/null
)

case "${_acceptLicenseAgreement}" in
  200)
    # is new pf, create admin user. 
    echo "INFO: new server found, must create admin"
    ## set script vars
    _password="$(get_value PING_IDENTITY_PASSWORD true)"
    _password=${_password:=2Federate}
    if test "$(isImageVersionGtEq 10.1.0)" -eq 0 ; then
      _adminRoles='["ADMINISTRATOR","USER_ADMINISTRATOR","CRYPTO_ADMINISTRATOR","EXPRESSION_ADMINISTRATOR"]'
    else
      _adminRoles='["ADMINISTRATOR","USER_ADMINISTRATOR","CRYPTO_ADMINISTRATOR"]'
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
        --data '{"username": "administrator", "password": "'"${_password}"'",
          "description": "Initial administrator user.", 
          "auditor": false,"active": true, 
          "roles": '"${_adminRoles}"' }' \
        "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/administrativeAccounts" \
        2>/dev/null
    )
    if test "${_createAdminUser}" != "200" ; then
      echo_red "$(jq -r . /tmp/create.admin)"
      echo_red "error attempting to create admin"
      exit 83
    fi
    ;;
  401)
    echo "INFO: found existing admin"
    ;;
  *)
    echo_red "$(jq -r . /tmp/license.acceptance)"
    echo_red "License Agreement Failed"
    exit 83
    ;;
esac