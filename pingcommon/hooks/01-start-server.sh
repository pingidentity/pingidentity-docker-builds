#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build
#
# Prints out variables and startup information when the server is started.
#
# This may be useful to "call home" or send a notification of startup to a command and control center
#

# shellcheck source=../lib.sh
. "${BASE}/lib.sh"

HOSTNAME=$(hostname)

echo_header "Ping Identity DevOps Docker Image" " STARTED: $(date)" "HOSTNAME: ${HOSTNAME}"

echo_header "Directory Variables"
echo_vars   BASE IN_DIR OUT_DIR SERVER_ROOT_DIR STAGING_DIR HOOKS_DIR SERVER_PROFILE_DIR BAK_DIR SECRETS_DIR LICENSE_DIR

echo_header "File Variables"
echo_vars   TOPOLOGY_FILE TAIL_LOG_FILES

echo_header "Server Profile"
echo_vars   SERVER_PROFILE_URL SERVER_PROFILE_BRANCH SERVER_PROFILE_PATH SERVER_PROFILE_UPDATE

echo_header "DevOps User/Key"
echo_vars   PING_IDENTITY_DEVOPS_USER PING_IDENTITY_DEVOPS_KEY

echo_header "License Key Info"
echo_vars   LICENSE_FILE_NAME LICENSE_SHORT_NAME LICENSE_VERSION

echo_header "Product Startup"
echo_vars   STARTUP_COMMAND STARTUP_FOREGROUND_OPTS STARTUP_FOREGROUND_OPTS VERBOSE PING_DEBUG

echo_header "Ping Product Info"
echo_vars   PING_PRODUCT LOCATION LDAP_PORT LDAPS_PORT HTTPS_PORT JMX_PORT 
echo_vars   TOPOLOGY_SIZE TOPOLOGY_PREFIX TOPOLOGY_SUFFIX USER_BASE_DN
echo_vars   PD_ENGINE_PUBLIC_HOSTNAME 
echo_vars   PF_ADMIN_PUBLIC_HOSTNAME PF_ENGINE_PUBLIC_HOSTNAME
echo_vars   PA_ADMIN_PUBLIC_HOSTNAME PA_ENGINE_PUBLIC_HOSTNAME
echo_vars   ROOT_USER_DN

echo_header "JVM Details"
echo_vars   MAX_HEAP_SIZE JVM_TUNING
