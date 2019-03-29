#!/usr/bin/env sh

docker container stop $(docker container ls -aq)
docker container rm $(docker container ls -aq)
docker rmi -f $(docker images "pingidentity/*" -q)
docker volume prune -f
exit 0