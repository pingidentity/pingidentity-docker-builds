#!/bin/env sh
set -ex

if test "${1}" = "start-server" ; then
    if ! test -z "${SERVER_PROFILE_URL}" ; then
      # deploy configuration if provided
      git clone ${SERVER_PROFILE_URL} /opt/server-profile | tee -a ${LOG_FILE}
      if ! test -z "${SERVER_PROFILE_BRANCH}" ; then
        cd /opt/server-profile
        git checkout ${SERVER_PROFILE_BRANCH}
        cd -
      fi
      cp -rf /opt/server-profile/* /opt/in
    fi

    cp -rf /opt/in/* /usr/share/nginx/html/delegator/

    # how do I start nginx ???
    /usr/sbin/nginx -g 'daemon off;'
else
    exec "$@"
fi