#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is started in the background immediately before 
#- the server within the container is started
#-
#- This is useful to implement any logic that needs to occur after the
#- server is up and running
#-
#- For example, enabling replication in PingDirectory, initializing Sync 
#- Pipes in PingDataSync or issuing admin API calls to PingFederate or PingAccess

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

set -e
echo_yellow "NOTE: PingAccess 6.1 natively supports data.json ingestion,"
echo_yellow "and is the recommended method for configuration. For more information, see:"
echo_yellow "https://pingidentity-devops.gitbook.io/devops/config/containeranatomy/profilestructures#for-pa-6-1-0"

echo "INFO: begin importing data.."

# # to Test an import call from the container you can use: 
# curl -k -v -X POST -u "Administrator:${PA_ADMIN_PASSWORD}" -H "Content-Type: application/json" -H "X-Xsrf-Header: PingAccess" \
#   -d @${STAGING_DIR}/instance/data/data.json \
#   https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/config/import

# to check on the status of an import use: 
# curl -k -v -X GET -u "Administrator:${PA_ADMIN_PASSWORD}" -H "Content-Type: application/json" -H "X-Xsrf-Header: PingAccess" \
#   https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/config/import/workflows/1
if test -f "${STAGING_DIR}/instance/data/data.json"
then
    # curl -ks -X POST -u "Administrator:${PA_ADMIN_PASSWORD}" -H "Content-Type: application/json" -H "X-Xsrf-Header: PingAccess" \
    # -d @${STAGING_DIR}/instance/data/data.json \
    # https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/config/import/workflows > /dev/null
    _out="/tmp/import.request.out"
    _import_http_code=$(
        curl \
            --insecure \
            --silent \
            --write-out '%{http_code}' \
            --request POST \
            --user "${ROOT_USER}:${PA_ADMIN_PASSWORD}" \
            --header "Content-Type: application/json" \
            --header "X-Xsrf-Header: PingAccess" \
            --data @${STAGING_DIR}/instance/data/data.json \
            --output ${_out} \
            https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/config/import/workflows \
            2>/dev/null
    )

    if ! test "${_import_http_code}" = "200"
    then
        echo_red "Import request error: ${_import_http_code}"
        cat "${_out}" | jq
        exit 85
    fi
    
    _import_id=$( jq -r .id "${_out}" )
    _out=/tmp/import.status.out
    _attempts=300
    while test ${_attempts} -gt 0
    do
        _import_http_code=$(
            curl \
                --insecure \
                --silent \
                --write-out '%{http_code}' \
                --request GET \
                --user "${ROOT_USER}:${PA_ADMIN_PASSWORD}" \
                --header "Content-Type: application/json" \
                --header "X-Xsrf-Header: PingAccess" \
                --output ${_out} \
                https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/config/import/workflows \
                2>/dev/null
        )

        if test "${_import_http_code}" = 200
        then
            _import_status=$( jq -r '.items[]|select(.id=='${_import_id}')|.status' "${_out}" )
            case "${_import_status}" in
                '' | 'In Progress')
                    echo "import in progress.."
                    sleep 2
                ;;
                Complete)
                    echo_green "Import done."
                    _attempts=0
                ;;
                Failed)
                    # clean failure, display error, bail
                    echo_red "Import failed."
                    jq -r '.items[]|select(.id==1)|.apiErrorView|.flash[0]' "${_out}"
                    exit 85
                ;;
                *)
                    # unexpected error
                    echo_red "Import status: ${_import_status}"
                    echo_red "ERROR: Unsuccessful Import"
                    exit 85 
                ;;
            esac
        else
            echo "There was an error retrieving import status, retrying in 3 seconds (HTTP Code: ${_import_http_code})"
            # Something is really wrong, retrying at most 3 times
            if test ${_attempts} -gt 3 
            then
                _attempts=3
            fi
            sleep 3
        fi
        _attempts=$(( _attempts - 1 ))
    done
fi