#!/usr/bin/env sh
set -x
heap=$(awk '$1~/MemAvailable/ {print int($2*0.9/1048576)}' /proc/meminfo)
jvmArgs="-Xmx${MAX_HEAP_SIZE:-${heap}m} -Xms${MAX_HEAP_SIZE:-${heap}m}"
localIP=$(ifconfig eth0 | awk '$1~/inet$/ {split($2,ip,":");print ip[2]}')
jmeterArgs=" -Djava.rmi.server.hostname=${localIP} -Dserver.rmi.ssl.disable=true -Djmeter.logfile=/var/log/jmeter.log -Dprometheus.ip=0.0.0.0"
exec java ${jvmArgs} -jar /opt/server/bin/ApacheJMeter.jar ${jmeterArgs} ${*:-${CMD}}