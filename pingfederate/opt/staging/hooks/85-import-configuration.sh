#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

_password="$( get_value PING_IDENTITY_PASSWORD true )"
if test -z "${_password}"
then
  echo_yellow "No PING_IDENTITY_PASSWORD found. Using default password"
  _password="2Federate"
fi

_importBulkConfig=$(
    curl \
        --insecure \
        --silent \
        --write-out '%{http_code}' \
        --request POST \
        --user "${ROOT_USER}:${_password}" \
        --header 'Content-Type: application/json' \
        --header 'X-XSRF-Header: PingFederate' \
        --header 'X-BypassExternalValidation: true' \
        --data "@${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}" \
        --output "/tmp/import.status.out" \
        "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/bulk/import?failFast=false" \
        2>/dev/null
)

if test "${_importBulkConfig}" = "200"
then
  echo "INFO: Removing Imported Bulk File"
  rm "${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}"

  if test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"
  then
    _replicateConfig=$(
        curl \
            --insecure \
            --silent \
            --write-out '%{http_code}' \
            --request POST \
            --user "${ROOT_USER}:${_password}" \
            --header 'Content-Type: application/json' \
            --header 'X-XSRF-Header: PingFederate' \
            --output "/tmp/replicate.status.out" \
            "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/cluster/replicate" \
            2>/dev/null
    )
    if test "${_replicateConfig}" != "200"
    then
      jq -r . "/tmp/replicate.status.out"
      echo_red "Unable replicate config"
      exit 85
    fi
  fi
else
  echo_red "$( jq -r . /tmp/import.status.out )"
  echo_red "Unable to import bulk config"
  exit 85
fi