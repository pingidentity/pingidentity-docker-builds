# #!/usr/bin/env sh
# #
# # Ping Identity DevOps - Docker Build Hooks
# #

# # BASE=${BASE:-/opt}
# # IN_DIR=${BASE}/in
# # OUT_DIR=${BASE}/out
# # SERVER_BITS_DIR=${BASE}/server
# # BAK_DIR=${BASE}/backup
# # LOGS_DIR=${BASE}/logs
# # STAGING_DIR=${BASE}/staging
# # SECRETS_DIR=${STAGING_DIR}/.sec
# # TOPOLOGY_FILE=${STAGING_DIR}/topology.json
# # HOOKS_DIR=${STAGING_DIR}/hooks
# # CONTAINER_ENV=${STAGING_DIR}/.env

# # SERVER_ROOT_DIR=${OUT_DIR}/instance

# # if test "${1}" = "start-server" ; then
#     PINGFEDERATE_PUBLIC_HOSTNAME=${PINGFEDERATE_PUBLIC_HOSTNAME:=localhost}
#     PINGFEDERATE_PUBLIC_PORT=${PINGFEDERATE_PUBLIC_PORT:=9031}
#     PINGFEDERATE_DELEGATOR_CLIENTID=${PINGFEDERATE_DELEGATOR_CLIENTID:=dadmin}
#     PINGDIRECTORY_PRIVATE_HOSTNAME=${PINGDIRECTORY_PRIVATE_HOSTNAME:=pingdirectory}
#     PINGDIRECTORY_PRIVATE_PORT=${PINGDIRECTORY_PRIVATE_PORT:=443}

#     echo "
# ##################################################################################
# #               Ping Identity DevOps Delegator Web Application
# ##################################################################################
# # 
# #     Configured with the following values.  
# # 
# #         PINGFEDERATE_PUBLIC_HOSTNAME: ${PINGFEDERATE_PUBLIC_HOSTNAME}
# #             PINGFEDERATE_PUBLIC_PORT: ${PINGFEDERATE_PUBLIC_PORT}
# #      PINGFEDERATE_DELEGATOR_CLIENTID: ${PINGFEDERATE_DELEGATOR_CLIENTID}
# #       PINGDIRECTORY_PRIVATE_HOSTNAME: ${PINGDIRECTORY_PRIVATE_HOSTNAME}
# #           PINGDIRECTORY_PRIVATE_PORT: ${PINGDIRECTORY_PRIVATE_PORT}
# # 
# #     To set via a docker run or .yaml just set them using examples below
# #
# #    docker run
# #           ...
# #           --env PINGFEDERATE_PUBLIC_HOSTNAME=myhost.mydomain.com
# #           ...
# #
# #      To use with '.yaml' file (use snippet below)
# #
# #    pingdirectry:
# #       environment: PINGFEDERATE_PUBLIC_HOSTNAME=myhost.mydomain.com
# ##################################################################################
# "

#     cd ${SERVER_ROOT_DIR}/html/delegator || container_failure "18" "Unable to cd to the delegator html directory"

#     sed -e "s/PF_HOST = 'localhost'/PF_HOST = '${PINGFEDERATE_PUBLIC_HOSTNAME}'/" \
#         -e "s/PF_PORT = '9031'/PF_PORT = '${PINGFEDERATE_PUBLIC_PORT}'/" \
#         -e "s/DADMIN_CLIENT_ID = 'dadmin'/DADMIN_CLIENT_ID = '${PINGFEDERATE_DELEGATOR_CLIENTID}'/" \
#         -e "s/^\/\/ window.DS_HOST = undefined;/window.DS_HOST = '${PINGDIRECTORY_PRIVATE_HOSTNAME}'/" \
#         -e "s/^\/\/ window.DS_PORT = undefined;/window.DS_PORT = '${PINGDIRECTORY_PRIVATE_PORT}'/" \
#         "example.config.js" > "config.js"

#     chmod 600 "config.js"

# #     cd /
# #     nginx -p "${SERVER_ROOT_DIR}/etc"
# # else
# #     exec "$@"
# # fi
