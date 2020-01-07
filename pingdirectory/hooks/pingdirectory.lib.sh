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
# If it does't respond after 8 iterations, then echo the messages passed
#
# parameters:  $1 - hostname
#              $2 - port
#              $3 - baseDN
waitUntilLdapUp ()
{
    _iCnt=1

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

        if test $_iCnt == 8; then
            _iCnt=0
            echo "May be a DNS/Firewall/Service/PortMapping Issue."
            echo "    Ensure that the container/pod can reach: $1:$2"
        fi

        _iCnt=$((_iCnt+1))
    done
}