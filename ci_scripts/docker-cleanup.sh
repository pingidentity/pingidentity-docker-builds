#!/usr/bin/env sh
set -x

docker container stop $(docker container ls -aq)
docker container rm $(docker container ls -aq)
docker image prune -f
docker rmi -f $(docker images "pingidentity/*" -q)
docker volume prune -f
exit 0