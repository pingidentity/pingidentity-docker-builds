#!/usr/bin/env sh
set -x

source /opt/utils.sh

function apply_server_profile ()
{
    if ! test -z "${SERVER_PROFILE_URL}" ; then
        # deploy configuration if provided
        git clone ${SERVER_PROFILE_URL} /opt/server-profile
        die_on_error 78 "Git clone failure" 
        if ! test -z "${SERVER_PROFILE_BRANCH}" ; then
            cd /opt/server-profile
            git checkout ${SERVER_PROFILE_BRANCH}
            cd -
        fi
        cp -af /opt/server-profile/${SERVER_PROFILE_PATH}/* /opt/in
    fi
    test -d ${IN_DIR}/instance && cp -af ${IN_DIR}/instance ${OUT_DIR}
}

function deploy_server_bits ()
{
  test -d "${SERVER_ROOT_DIR}" || cp -af /opt/server ${SERVER_ROOT_DIR}
}


echo "Initializing server for the first time"

# if this hook is provided it can be executed early on
run_if present ${IN_DIR}/hooks/10-before-copying-bits.sh

# lay down the bits from the immutable volume to the runtime volume
deploy_server_bits

# if this hook is provided it can be used to execute something before the server-profile is applied
run_if present ${IN_DIR}/hooks/11-before-applying-server-profile.sh

# apply the server profile provided
apply_server_profile

# environment variables will be provided by the server profile
test -f ${IN_DIR}/env_vars && source ${IN_DIR}/env_vars

