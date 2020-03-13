#!/usr/bin/env bash
test -n "${VERBOSE}" && set -x

# stop containers
_containers=$( docker container ls -q | sort | uniq )
test -n "${_containers}" && docker container stop ${_containers}

_containers=$( docker container ls -aq | sort | uniq )
test -n "${_containers}" && docker container rm -f ${_containers}


# clean all images if full clean is requested
if test "${1}" = "full" ;
then
    _images=$( docker image ls -q | sort | uniq )
    test -n "${_images}" && docker image rm -f ${_images}
    docker system prune -f
else
    # clean our pingidentity images except foundation images
    _images=$( docker image ls --format '{{.Repository}} {{.ID}}' "pingidentity/*" | awk '$1 !~ /(base|common|jvm)$/ {print $2}'|sort|uniq)
    test -n "${_images}" && docker image rm -f "${_images}"
fi

exit 0