#!/usr/bin/env sh

getFirstHostInTopology ()
{
    jq -r '.|[.serverInstances[]|select(.product=="DIRECTORY")]|.[0]|.hostname' < "${TOPOLOGY_FILE}"
}

getIP ()
{
    nslookup "${1}"  2>/dev/null | awk '$0 ~ /^Address 1/ {print $3; exit 0}'
}

# Loops until a specific ldap host, port, basedn can be returned successfully
waitUntilLdapUp ()
{
    while true; do
        # shellcheck disable=SC2086
        ldapsearch \
            --terse \
            --suppressPropertiesFileComment \
            --hostname "$1" \
            --port "$2" \
            --useSSL \
            --trustAll \
            --baseDN "$3" \
            --scope base "(&)" 1.1 2>/dev/null && break

        sleep_at_most 15
    done
}