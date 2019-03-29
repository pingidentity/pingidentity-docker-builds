#!/usr/bin/env sh
${VERBOSE} && set -x

wipe=""
for p in datasync access datasync directory federate base datacommon common ; do
    wipe="${wipe} pingidentity/ping${p} pingidentity/ping${p}:edge"
    if test -f ping${p}/versions ; then
        for VERSION in $( cat ping${p}/versions ) ; do
            wipe="${wipe} pingidentity/ping${p}:${VERSION}-edge"
        done
    fi
done

docker image rm -f ${wipe} 2>/dev/null
docker image prune -f
