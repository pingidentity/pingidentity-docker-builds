#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=/dev/null
test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"

####
# cleanup the replication topology in case it has some defunct servers
###

# NEW 7.3 remove-defunct-server --serverInstanceName c68f0ce0e576 --ignoreOnline -D cn=administrator -w 2FederateM0re -n

status=$( dsreplication status --script-friendly )
firstLiveServer=$( echo "${status}" | awk 'BEGIN {s=""} $1~/Server:/{s=$2} $1~/Entries:/ && $2!~/N\/A/{print s;exit 0}' )
# shellcheck disable=2086,2039
dsconfig \
    --no-prompt \
    --useSSL \
    --trustAll \
    --hostname "${firstLiveServer}" \
    --port ${LDAPS_PORT} \
    set-global-configuration-prop \
    --set force-as-master-for-mirrored-data:true
for defunctServer in $( echo "${status}" | awk '$0 ~ /^Error on/ {split($3,a,":");print a[1]}' ) ; do
    remove-defunct-server \
        --serverInstanceName "${defunctServer}" \
        --bindDN "${ROOT_USER_DN}" \
        --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
        --enableDebug \
        --globalDebugLevel verbose \
        --no-prompt
done
# shellcheck disable=2086,2039
dsconfig \
    --no-prompt \
    --useSSL \
    --trustAll \
    --hostname "${firstLiveServer}" \
    --port ${LDAPS_PORT} \
    set-global-configuration-prop \
    --set force-as-master-for-mirrored-data:false
