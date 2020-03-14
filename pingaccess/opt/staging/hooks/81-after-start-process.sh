#!/usr/bin/env sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

test -n "${INITIAL_ADMIN_PASSWORD}" && echo "WARNING: INITIAL_ADMIN_PASSWORD is deprecated, use PA_ADMIN_PASSWORD"
_pwCheck=$( curl -ks --write-out %{http_code} --output /dev/null -X GET \
  -u administrator:${PA_ADMIN_PASSWORD} -H "X-Xsrf-Header: PingAccess" \
  https://localhost:9000/pa-admin-api/v3/users/1 )
if test "$_pwCheck" -gt 200 -o "${PA_ADMIN_PASSWORD}" = "2Access" ; then
  run_hook "83-change-password.sh" ; fi

echo "Checking for data.json to import.."
if test -f "${STAGING_DIR}/instance/data/data.json" ; then
  if test -f "${STAGING_DIR}/instance/conf/pa.jwk" ; then
    if test -f "${STAGING_DIR}/instance/data/PingAccess.mv.db" ; then
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