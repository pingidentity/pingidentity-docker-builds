#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook will import data into the PingDirectory if there are data files
#- included in the server profile data directory.
#-
#- If a .template file is provided, then makeldif will be run to create the .ldif
#- file to be imported.
#-
#- If there are any skipped or rejected entries, an error message will be printed
#- and the container will exit, unless the environment variable
#- `PD_IMPORT_CONTINUE_ON_ERROR=true` is provided when the container is run.
#
${VERBOSE} && set -x


# shellcheck source=../pingcommon/lib.sh
. "${BASE}/lib.sh"

#
#
# TODO Check the template stuff and possibly move to some hook before 183-run-setup
# TODO Keeping script below for possible future use
#
# stage 1, we check if there are make-ldif template to generate synthetic data
#    if ! test -z "${MAKELDIF_USERS}" \
#        && test ${MAKELDIF_USERS} -gt 0 \
#        && ! test -z "$( find "${STAGING_DIR}/data" -type f -iname \*.template 2>/dev/null )" ; then
#        # shellcheck disable=SC2044
#        for template in $( find "${STAGING_DIR}/data" -type f -iname \*.template 2>/dev/null ) ; do 
#            "${SERVER_ROOT_DIR}/bin/make-ldif" \
#                --templateFile "${template}"  \
#                --ldifFile "${template%.*}.ldif.gz" \
#                --numThreads 3 \
#                --compress
#        done
#    fi
