#!/usr/bin/env sh

if test "${1}" = "start-server" ; then
    ${PINGFEDERATE_PUBLIC_HOSTNAME:=localhost}
    ${PINGFEDERATE_PUBLIC_PORT:=9031}
    ${PINGFEDERATE_DELEGATOR_CLIENTID:=dadmin}

    echo "
##################################################################################
#               Ping Identity DevOps Delegator Web Application
##################################################################################
# 
#     Configured with the following values.  
# 
#         PINGFEDERATE_PUBLIC_HOSTNAME: ${PINGFEDERATE_PUBLIC_HOSTNAME}
#             PINGFEDERATE_PUBLIC_PORT: ${PINGFEDERATE_PUBLIC_PORT}
#      PINGFEDERATE_DELEGATOR_CLIENTID: ${PINGFEDERATE_DELEGATOR_CLIENTID}
# 
#     To set via a docker run or .yaml just set them using examples below
#
#    docker run
#           ...
#           --env PINGFEDERATE_PUBLIC_HOSTNAME=myhost.mydomain.com
#           ...
#
#      To use with '.yaml' file (use snippet below)
#
#    pingdirectry:
#       environment: PINGFEDERATE_PUBLIC_HOSTNAME=myhost.mydomain.com
##################################################################################
"

    cd /usr/share/nginx/html/delegator

    sed -e "s/PF_HOST = 'localhost'/PF_HOST = '${PINGFEDERATE_PUBLIC_HOSTNAME}'/" \
        -e "s/PF_PORT = '9031'/PF_PORT = '${PINGFEDERATE_PUBLIC_PORT}'/" \
        -e "s/DADMIN_CLIENT_ID = 'dadmin'/DADMIN_CLIENT_ID = '${PINGFEDERATE_DELEGATOR_CLIENTID}'/" \
        "example.config.js" > "config.js"

    chmod 644 "config.js"

    cd /
    nginx -g 'daemon off;'
else
    exec "$@"
fi
