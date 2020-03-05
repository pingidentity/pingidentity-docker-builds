#!/usr/bin/env bash
set -x

# stop and remove containers and associated volumes if any
_containers=$(docker container ls -aq)
if test -n "${_containers}" ;
then
    docker container stop ${_containers}
    docker container rm -fv ${_containers}
fi

# clean our pingidentity images except foundation images
_images=$(docker image ls --format '{{.Repository}} {{.ID}}' "pingidentity/*" | awk '$1 !~ /(base|common|jvm)$/ {print $2}'|sort|uniq)
test -n "${_images}" && docker rmi -f "${_images}"

# clean all images if full clean is requested
if test ${1} = "full" ;
then
    _images=$(docker image ls -q|sort|uniq)
    test -n "${_images}" && docker rmi -f ${_images}
fi

docker image prune -f
docker volume prune -f
docker network prune -f
docker system prune -f
exit 0