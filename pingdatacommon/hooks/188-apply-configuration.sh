#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

if test -d "${STAGING_DIR}/dsconfig" ; then
    for batch in $( find "${STAGING_DIR}/dsconfig/" -iname \*.dsconfig 2>/dev/null | sort | uniq ) ; do
        envsubst < "${batch}" >> "${SERVER_ROOT_DIR}/tmp/config.batch"
        # this guards against provided config batches that don't end with a blank line
        echo >> "${SERVER_ROOT_DIR}/tmp/config.batch"
    done
fi

cat >>"${SERVER_ROOT_DIR}/tmp/config.batch" <<END
dsconfig set-connection-handler-prop \
    --handler-name "HTTPS Connection Handler"  \
    --reset web-application-extension

END

if test "${PING_DEBUG}" == "true" ; then
  DSCONFIG_OPT="--verbose"
else
  DSCONFIG_OPT="--quiet"
  echo "Running dsconfig in QUIET mode (because PING_DEBUG=${PING_DEBUG})."
  echo "Please refer to ${SERVER_ROOT_DIR}/logs/config-audit.log for audit."
fi

"${SERVER_ROOT_DIR}/bin/dsconfig" \
    --no-prompt \
    --suppressMirroredDataChecks \
    --offline \
    ${DSCONFIG_OPT} \
    --batch-file "${SERVER_ROOT_DIR}/tmp/config.batch"
