#!/usr/bin/env sh
set -x
# shellcheck source=/dev/null
test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"
# shellcheck source=../pingcommon/lib.sh
test -f "${BASE}/lib.sh" && . "${BASE}/lib.sh"
# shellcheck source=pingdirectory.lib.sh
test -f "${BASE}/pingdirectory.lib.sh" && . "${BASE}/pingdirectory.lib.sh"


# jq -r '.|.serverInstances[]|select(.product=="DIRECTORY")|.hostname' < /opt/staging/topology.json
FIRST_HOSTNAME=$( getFirstHostInTopology )
FQDN=$( hostname -f )
echo "Waiting until DNS lookup works for ${FQDN}" 
while true; do
  echo "Running nslookup test"
  nslookup "${FQDN}" && break

  echo "Sleeping for a few seconds"
  sleep_at_most 5
done

MYIP=$( getIP ${FQDN}  )
FIRST_IP=$( getIP "${FIRST_HOSTNAME}" )

if test "${MYIP}" = "${FIRST_IP}"  && test -d "${STAGING_DIR}/data" ; then
    # stage 1, we check if there are make-ldif template to generate synthetic data
    if test ${MAKELDIF_USERS} -gt 0 && ! test -z "$( find "${STAGING_DIR}/data" -type f -iname \*.template 2>/dev/null )" ; then
        # shellcheck disable=SC2044
        for template in $( find "${STAGING_DIR}/data" -type f -iname \*.template 2>/dev/null ) ; do 
            envsubst < "${template}" > /tmp/make-ldif.template
            "${SERVER_ROOT_DIR}/bin/make-ldif" \
                --templateFile /tmp/make-ldif.template  \
                --ldifFile "${template%.*}.ldif.gz" \
                --numThreads 3 \
                --compress
        done
    fi
    # stage 2, we check if there are LDIF templates that we have to run through env subst
    # shellcheck disable=SC2044
    for template in $( find "${STAGING_DIR}/data" -type f -iname \*.ldif.subst ) ; do 
        envsubst <"${template}" >"${template%.*}.ldif"
    done

    # stage 3, we build the list of all the eligible candidate data files
    # and import them
    if ! test -z "$( find "${STAGING_DIR}/data" -type f \( -iname \*.ldif -o -iname \*.ldif.gz \) 2>/dev/null )" ; then
        for backend in $( find "${STAGING_DIR}/data/" -type f \( -iname \*.ldif -o -iname \*.ldif.gz \) -exec basename {} \; | sed 's/[0-9][0-9]-//' | sed 's/-.*$//' | sort | uniq ) ; do
            filesToImport=""
            # shellcheck disable=SC2086 
            for ldifFile in $( ls "${STAGING_DIR}"/data/??-${backend}-*.ldif "${STAGING_DIR}"/data/??-${backend}-*.ldif.gz 2>/dev/null | sort ) ; do
                filesToImport="${filesToImport} -l ${ldifFile}"
            done
            # shellcheck disable=SC2086
            # if we double quote filesToImport the import command will fail
            "${SERVER_ROOT_DIR}/bin/import-ldif" \
            --rejectFile "${SERVER_ROOT_DIR}/logs/tools/import-ldif.rejected" \
            --skipFile "${SERVER_ROOT_DIR}/logs/tools/import-ldif.skipped" \
            --clearBackend \
            --backendID "${backend}" \
            --addMissingRdnAttributes \
            --overwriteExistingEntries \
            ${filesToImport}
        done
    fi
fi