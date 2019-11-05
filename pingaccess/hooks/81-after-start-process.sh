#!/usr/bin/env sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

run_hook "83-create-initial-password.sh"


echo "Checking for data.json to import.."
if ! test -f "${STAGING_DIR}/instance/conf/pa.jwk" ; then
  echo "INFO: No file named /instance/conf/pa.jwk found"
fi
if test -f "${STAGING_DIR}/instance/data/data.json" ; then
  if test -f "${STAGING_DIR}/instance/data/PingAccess.mv.db" ; then
    echo "INFO: file named /instance/data/data.json found and will overwrite /instance/data/PingAccess.mv.db"
  else
    echo "INFO: file named /instance/data/data.json"
  fi
else
  echo "INFO: No file named /instance/data/data.json found"
fi
if test -f "${STAGING_DIR}/instance/conf/pa.jwk" && test -f "${STAGING_DIR}/instance/data/data.json"; then
  run_hook "85-import-initial-configuration.sh"
else
  echo "INFO: skipping config import"
fi