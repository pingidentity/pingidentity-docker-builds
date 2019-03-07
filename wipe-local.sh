#!/usr/bin/env sh

for p in datasync access datasync directory federate base datacommon common ; do
    docker image rm pingidentity/ping${p}
done

docker image prune -f
