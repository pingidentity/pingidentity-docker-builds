#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
# Prints out variables and startup information when the server is started.
#
# This may be useful to "call home" or send a notification of startup to a command and control center
#

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

#######################################################################################################
echo_header "Directory Variables"
echo_vars   BASE IN_DIR OUT_DIR SERVER_ROOT_DIR STAGING_DIR HOOKS_DIR SERVER_PROFILE_DIR BAK_DIR LOGS_DIR SECRETS_DIR LICENSE_DIR

echo_header "File Variables"
echo_vars   TOPOLOGY_FILE TAIL_LOG_FILES COLORIZE_LOGS

echo_header "Server Profile"
echo_vars   SERVER_PROFILE_URL SERVER_PROFILE_BRANCH SERVER_PROFILE_PATH SERVER_PROFILE_UPDATE

echo_header "DevOps User/Key"
echo_vars   PING_IDENTITY_DEVOPS_USER PING_IDENTITY_DEVOPS_KEY

echo_header "License Key Info"
echo_vars   LICENSE_FILE_NAME LICENSE_SHORT_NAME LICENSE_VERSION

echo_header "Product Startup"
echo_vars   STARTUP_COMMAND STARTUP_FOREGROUND_OPTS STARTUP_BACKGROUND_OPTS VERBOSE PING_DEBUG

echo_header "Orchestration Info"
echo_vars   ORCHESTRATION_TYPE

echo_header "Ping Product Info"
echo_vars   PING_PRODUCT LOCATION LDAP_PORT LDAPS_PORT HTTPS_PORT JMX_PORT 
echo_vars   USER_BASE_DN
echo_vars   PD_ENGINE_PUBLIC_HOSTNAME 
echo_vars   PF_ADMIN_PUBLIC_HOSTNAME PF_ENGINE_PUBLIC_HOSTNAME
echo_vars   PA_ADMIN_PUBLIC_HOSTNAME PA_ENGINE_PUBLIC_HOSTNAME
echo_vars   ROOT_USER_DN

echo_header "JVM Details"
echo_vars   MAX_HEAP_SIZE JVM_TUNING

# If there are validations that have failed, then exit
if test "${_validationFailed}" == true ; then
    echo_red "Please resolve the validation issues!"
    exit 4
else
    echo ""
fi