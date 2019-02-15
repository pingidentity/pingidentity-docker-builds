#!/bin/sh
echo listening for pingaccess heartbeat
while true ; do
    echo -n .
    curl -k https://localhost:443/pa/heartbeat.ping >/dev/null 2>/dev/null && break
    sleep 1
done
echo pingaccess is available

####
# execute post start configuration ?
####