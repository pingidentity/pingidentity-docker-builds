#!/bin/sh
set -ex

while true ; do
    curl -k https://localhost:443/directory/v1/ >/dev/null 2>/dev/null && break
    sleep 1
done

if test -f /opt/in/postStart.sh ; then
    sh -x /opt/in/postStart.sh
fi