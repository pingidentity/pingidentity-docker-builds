#!/bin/env sh
set -ex

if test "${1}" = "start-server" ; then
	if ! test -z "${SERVER_PROFILE_URL}" ; then
		# clone server profile if provided
		git clone ${SERVER_PROFILE_URL} /opt/server-profile
        cp -rf /opt/server-profile /opt/in
	fi

    cp -rf /opt/in/* /usr/share/nginx/html/delegator/

    # how do I start nginx ???
    nginx -g 'daemon off;'
else
    exec "$@"
fi