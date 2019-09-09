#!/usr/bin/env sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

run_hook "83-create-initial-password.sh"


echo "Checking for data.json to import.."
if ! test -f "${STAGING_DIR}/instance/conf/pa.jwk" ; then
  echo "INFO: No file named /instance/conf/pa.jwk found"
fi
if ! test -f "${STAGING_DIR}/instance/data/data.json" ; then
  echo "INFO: No file named /instance/data/data.json found"
fi
if test -f "${STAGING_DIR}/instance/data/PingAccess.mv.db" ; then
  echo "INFO: File named /instance/data/PingAccess.mv.db found"
fi
if test -f "${STAGING_DIR}/instance/conf/pa.jwk" && test -f "${STAGING_DIR}/instance/data/data.json" && test ! -f "${STAGING_DIR}/instance/data/PingAccess.mv.db"; then
  run_hook "85-import-initial-configuration.sh"
else
  echo "INFO: skipping config import"
fi