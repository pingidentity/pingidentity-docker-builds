#!/usr/bin/env sh
set -x

if test -d "${STAGING_DIR}/data" && ! test -z "$( find "${STAGING_DIR}/data" -type f \( -iname \*.ldif -o -iname \*.ldif.gz \) 2>/dev/null )" ; then
    for backend in $( find "${STAGING_DIR}/data/" -type f \( -iname \*.ldif -o -iname \*.ldif.gz \) -exec basename {} \; | sed 's/[0-9][0-9]-//' | sed 's/-.*$//' | sort | uniq ) ; do
        filesToImport=""
        for ldifFile in $( ls "${STAGING_DIR}"/data/??-${backend}-*.ldif "${STAGING_DIR}"/data/??-${backend}-*.ldif.gz | sort ) ; do
            filesToImport="${filesToImport} -l ${ldifFile}"
        done    
        "${SERVER_ROOT_DIR}/bin/import-ldif" \
        --rejectFile "${SERVER_ROOT_DIR}/logs/tools/import-ldif.rejected" \
        --skipFile "${SERVER_ROOT_DIR}/logs/tools/import-ldif.skipped" \
        --clearBackend \
        --backendID "${backend}" \
        "${filesToImport}"
    done
fi