#!/usr/bin/env sh
set -x

if test -d "${STAGING_DIR}/config" && ! test -z "$( ls -A "${STAGING_DIR}/config/"*.dsconfig 2>/dev/null )" ; then
    for batch in $( find "${STAGING_DIR}/config/" -iname \*.dsconfig 2>/dev/null | sort | uniq ) ; do
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

"${SERVER_ROOT_DIR}/bin/dsconfig" \
    --no-prompt \
    --suppressMirroredDataChecks \
    --offline \
    --batch-file "${SERVER_ROOT_DIR}/tmp/config.batch"
