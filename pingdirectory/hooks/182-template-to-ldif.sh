#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook will make-ldif from templates to ldif file in the same directory
#- that will be used during the manage-profile setup
#
${VERBOSE} && set -x


# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

#
# If we are the GENESIS state, then we need to import data long with any LDIF files
#
if test "${PD_STATE}" == "GENESIS" ; then
    echo "PD_STATE is GENESIS ==> Processing Templates"
    
    LDIF_DIR="${STAGING_DIR}/pd.profile/ldif/userRoot"
    TEMPLATE_DIR="${LDIF_DIR}"
    echo "Processing Templates with ${MAKELDIF_USERS} users..."

    if ! test -z "${MAKELDIF_USERS}" \
        && test ${MAKELDIF_USERS} -gt 0 \
        && ! test -z "$( find "${TEMPLATE_DIR}" -type f -iname \*.template 2>/dev/null )" ; then
        # shellcheck disable=SC2044
        for template in $( find "${TEMPLATE_DIR}" -type f -iname \*.template 2>/dev/null ) ; do 
            "${SERVER_ROOT_DIR}/bin/make-ldif" \
                --templateFile "${template}"  \
                --ldifFile "${template%.*}.ldif" \
                --numThreads 3
        done
    fi
    
else
    echo "PD_STATE is not GENESIS ==> Skipping Templates"
fi

