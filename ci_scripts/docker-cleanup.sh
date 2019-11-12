#!/usr/bin/env bash
set -x
test ${1} = "full" && full="true"
docker container stop $(docker container ls -aq)
docker container rm $(docker container ls -aq)
docker image prune -f
docker volume prune -f
test $full = "true" && docker rmi -f $(docker image ls --format '{{.Repository}} {{.ID}}' "pingidentity/*" | awk '$1 !~ /(base|common)$/ {print $2}')
docker image prune -f
exit 0