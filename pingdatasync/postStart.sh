#!/bin/sh
set -ex

while true ; do
    curl -s -o /dev/null -k https://localhost:443/directory/v1/ 2>&1 && break
    sleep 1
done

if test -f /opt/in/postStart.sh ; then
    sh -x /opt/in/postStart.sh
fi