#!/usr/bin/env sh
set -x

docker container stop $(docker container ls -aq)
docker container rm $(docker container ls -aq)
docker rmi -f $(docker images "pingidentity/*" -q)
docker image prune -f
docker volume prune -f
exit 0