#!/usr/bin/env sh

set -x

docker image prune -f
docker rmi -f pingidentity/pingcommon
docker rmi -f pingidentity/pingcdataommon
docker rmi -f $(docker images "pingidentity/pingbase*" -q)
exit 0