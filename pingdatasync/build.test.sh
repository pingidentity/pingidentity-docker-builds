#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
attempts=10
interval=30
errorCode=88

while true ; do
    isPipeStarted=$( ldapsearch -T --terse -b "cn=Sync Pipe Monitor: pingdirectory_source-to-pingdirectory_destination,cn=monitor" '(&)' started|awk '$1 ~ /started/ {print $2}' )
    if test "${isPipeStarted}" = "true" ; then
        exit 0
    fi
    if test ${attempts} -gt 0 ; then
        attempts=$(( attempts - 1 ))
        sleep ${interval}
    else
        break
    fi
done
exit ${errorCode}

# Same thing with jq for the record
#ldapsearch -T --outputFormat json --terse -b "cn=Sync Pipe Monitor: pingdirectory_source-to-pingdirectory_destination,cn=monitor" '(&)' started | jq -r '.attributes[]|select(.name=="started")|.values[0]'