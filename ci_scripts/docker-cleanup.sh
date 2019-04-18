#!/usr/bin/env sh
set -x

docker container stop $(docker container ls -aq)
docker container rm $(docker container ls -aq)
docker image prune -f
docker rmi -f $(docker image ls --format '{{.Repository}} {{.ID}}' "pingidentity/*" | awk '$1 !~ /(base|common)$/ {print $2}')
docker volume prune -f
exit 0