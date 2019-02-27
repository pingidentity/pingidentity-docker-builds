#!/usr/bin/env sh

getFirstHostInTopology ()
{
    jq -r '.|[.serverInstances[]|select(.product=="DIRECTORY")]|.[0]|.hostname' < "${TOPOLOGY_FILE}"
}

getIP ()
{
    nslookup "${1}"  2>/dev/null | awk '$0 ~ /^Address 1/ {print $3; exit 0}'
}