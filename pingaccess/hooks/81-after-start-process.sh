#!/usr/bin/env sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

run_hook "83-create-initial-password.sh"

if test "${RUN_PLAN}" = "START" ; then
  echo "Check for configuration to import.."
  if ! test -f "${STAGING_DIR}/instance/conf/pa.jwk" ; then
    echo "INFO: No 'pa.jwk' found in /instance/conf"
  fi
  if ! test -f "${STAGING_DIR}/instance/data/data.json" ; then
    echo "INFO: No file named 'data.json' found in /instance/data"
    echo "INFO: skipping config import"
  fi
  if test -f "${STAGING_DIR}/instance/conf/pa.jwk" && test -f "${STAGING_DIR}/instance/data/data.json" ; then
    run_hook "85-import-initial-configuration.sh"
  fi
fi