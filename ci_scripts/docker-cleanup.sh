#!/usr/bin/env sh

docker container stop $(docker container ls -aq)
docker container rm $(docker container ls -aq)
docker image prune -f
docker volume prune -f
exit 0