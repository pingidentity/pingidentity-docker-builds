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

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"
set -e
echo "importing data.."

# # to Test an import call from the container you can use: 
# curl -k -v -X POST -u "Administrator:${PA_ADMIN_PASSWORD}" -H "Content-Type: application/json" -H "X-Xsrf-Header: PingAccess" \
#   -d @${STAGING_DIR}/instance/data/data.json \
#   https://localhost:9000/pa-admin-api/v3/config/import

# to check on the status of an import use: 
# curl -k -v -X GET -u "Administrator:${PA_ADMIN_PASSWORD}" -H "Content-Type: application/json" -H "X-Xsrf-Header: PingAccess" \
#   https://localhost:9000/pa-admin-api/v3/config/import/workflows/1

curl -k --silent -X POST -u "Administrator:${PA_ADMIN_PASSWORD}" -H "Content-Type: application/json" -H "X-Xsrf-Header: PingAccess" \
  -d @${STAGING_DIR}/instance/data/data.json \
  https://localhost:9000/pa-admin-api/v3/config/import/workflows > /dev/null

while true ; do
  _import_status=$(curl -kv -u "Administrator:${PA_ADMIN_PASSWORD}" -H "Content-Type: application/json" -H "X-Xsrf-Header: PingAccess" https://localhost:9000/pa-admin-api/v3/config/import/workflows | jq '.items[-1].status')
  if test "${_import_status}" = '"In Progress"' ; then
    sleep 1
  else
    test "${_import_status}" = '"Complete"' && break
  fi
  die_on_error 85 "Unsuccessful import"
done