#!/usr/bin/env sh
set -x
heap=$(awk '$1~/^MemFree:$/{m=1024;if ($3~/^kB$/){m=1} mem=int(0.9*$2/(1024*m)); if (mem<384){mem=384;} print mem;}' /proc/meminfo)
if test "${MAX_HEAP_SIZE}" = "AUTO" ;
then
    jvmArgs="-Xmx${heap}m -Xms${heap}m"
else
    jvmArgs="-Xmx${MAX_HEAP_SIZE} -Xms${MAX_HEAP_SIZE}"
fi
localIP=$(ifconfig eth0 | awk '$1~/inet$/ {split($2,ip,":");print ip[2]}')
jmeterArgs=" -Djava.rmi.server.hostname=${localIP} -Dserver.rmi.ssl.disable=true -Djmeter.logfile=/var/log/jmeter.log -Dprometheus.ip=0.0.0.0"
exec java ${jvmArgs} -jar /opt/server/bin/ApacheJMeter.jar ${jmeterArgs} ${*:-${CMD}}