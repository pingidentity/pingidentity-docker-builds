#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
# Prints out variables and startup information when the server is started.
#
# This may be useful to "call home" or send a notification of startup to a command and control center
#

# shellcheck source=./pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

#######################################################################################################

# warn about any UNSAFE_ or deprecated variables
print_variable_warnings

#
# Flag used to track any validation errors (set by the echo_vars below).  If errors are found, then this
# flag will be set to true and later a message and exit will occur.
#
_validationFailed=false

echo_header "Docker Image Information"
echo_vars IMAGE_VERSION IMAGE_GIT_REV HOST_NAME DOMAIN_NAME

echo_header "Directory Variables"
echo_vars BASE IN_DIR OUT_DIR SERVER_ROOT_DIR STAGING_DIR HOOKS_DIR SERVER_PROFILE_DIR BAK_DIR LOGS_DIR SECRETS_DIR LICENSE_DIR

echo_header "File Variables"
echo_vars TOPOLOGY_FILE TAIL_LOG_FILES COLORIZE_LOGS

echo_header "Server Profile"
echo_vars SERVER_PROFILE_URL SERVER_PROFILE_BRANCH SERVER_PROFILE_PATH SERVER_PROFILE_UPDATE

echo_header "Security Checks"
echo_vars SECRUITY_CHECKS_STRICT SECURITY_CHECKS_FILENAME

if test -n "${VAULT_TYPE}"; then
    echo_header "Vault/Secrets Management"
    echo_vars VAULT_TYPE VAULT_ADDR
fi

echo_header "DevOps User/Key"
echo_vars PING_IDENTITY_DEVOPS_USER PING_IDENTITY_DEVOPS_KEY

echo_header "License Key Info"
echo_vars LICENSE_FILE_NAME LICENSE_SHORT_NAME LICENSE_VERSION MUTE_LICENSE_VERIFICATION

echo_header "Product Startup"
echo_vars STARTUP_COMMAND STARTUP_FOREGROUND_OPTS STARTUP_BACKGROUND_OPTS VERBOSE PING_DEBUG CLEAN_STAGING_DIR

echo_header "Orchestration Info"
echo_vars ORCHESTRATION_TYPE

if test "${ORCHESTRATION_TYPE}" = "KUBERNETES"; then
    echo_vars K8S_CLUSTERS K8S_CLUSTER K8S_SEED_CLUSTER K8S_NUM_REPLICAS K8S_POD_HOSTNAME_PREFIX K8S_POD_HOSTNAME_SUFFIX K8S_SEED_HOSTNAME_SUFFIX K8S_INCREMENT_PORTS
fi

if test "${ORCHESTRATION_TYPE}" = "COMPOSE"; then
    echo_vars COMPOSE_SERVICE_NAME
fi

echo_header "Ping Product Info"
echo_vars PING_PRODUCT LOCATION LDAP_PORT LDAPS_PORT HTTPS_PORT JMX_PORT
echo_vars USER_BASE_DN
echo_vars PD_ENGINE_PUBLIC_HOSTNAME
echo_vars PF_ADMIN_PUBLIC_HOSTNAME PF_ENGINE_PUBLIC_HOSTNAME
echo_vars PA_ADMIN_PUBLIC_HOSTNAME PA_ENGINE_PUBLIC_HOSTNAME
echo_vars PF_ADMIN_PUBLIC_BASEURL
echo_vars ROOT_USER_DN
echo_vars ADDITIONAL_SETUP_ARGS

echo_header "JVM Details"
echo_vars MAX_HEAP_SIZE JVM_TUNING

echo_bar

# If there are validations that have failed, then exit
if test "${_validationFailed}" = true; then
    echo_red "Please resolve the validation issues!"
    exit 4
else
    echo ""
fi
