#!/usr/bin/env sh

for p in base datasync access datasync directory federate ; do
    docker push pingidentity/ping${p} || exit 77
done