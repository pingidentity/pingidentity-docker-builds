#- # Ping Identity Docker Image - `pingbase`
#-
#- This docker image provides a base image for all Ping Identity DevOps
#- product images.
#-
FROM scratch
LABEL	name="Ping Identity Docker Image" \
        maintainer="devops_program@pingidentity.com" \
		license="Ping Identity Proprietary" \
		vendor="Ping Identity Corp."
# If an env variable is needed to set other env variables, it must be
# set in a separate statement before it is needed (no line continuation)

# the image base /might/ be changed at build-time but
# be aware that the entrypoint will have to be
# overridden to reflect the change
#-- Location of the top level directory where everything is located in
#-- image/container
ARG BASE
ENV BASE=${BASE:-/opt} \
#-- the default administrative user for PingData
    ROOT_USER="administrator" \
    JAVA_HOME=/opt/java
#-- Path to the staging area where the remote and local server profiles
#-- can be merged
ENV STAGING_DIR=${BASE}/staging \
#-- Path to the runtime volume
    OUT_DIR=${BASE}/out
#-- Path from which the runtime executes
ENV SERVER_ROOT_DIR=${OUT_DIR}/instance
#-- Location of a local server-profile volume
ENV IN_DIR=${BASE}/in \
#-- Path to the server bits
    SERVER_BITS_DIR=${BASE}/server \
#-- Path to a volume generically used to export or backup data
    BAK_DIR=${BASE}/backup \
#-- Path to a volume generically used for logging
    LOGS_DIR=${BASE}/logs \

# Legal requirement to explicitly accept the terms of the PingIdentity License
#-- Must be set to 'YES' for the container to start
    PING_IDENTITY_ACCEPT_EULA=NO \

#-- File name for devops-creds passed as a Docker secret
    PING_IDENTITY_DEVOPS_FILE=devops-secret \


#-- Path to a manifest of files expected in the staging dir on first image startup
    STAGING_MANIFEST=${BASE}/staging-manifest.txt \
#-- Whether to clean the staging dir when the image starts
    CLEAN_STAGING_DIR=false \
#-- Default path to the secrets
    SECRETS_DIR=/run/secrets \
#-- Path to the topology file
    TOPOLOGY_FILE=${STAGING_DIR}/topology.json \
#-- Path where all the hooks scripts are stored
    HOOKS_DIR=${STAGING_DIR}/hooks \
#-- Environment Property file use to share variables between scripts in container
    CONTAINER_ENV=${STAGING_DIR}/.env \

#-- Path where the remote server profile is checked out or cloned before
#-- being staged prior to being applied on the runtime
    SERVER_PROFILE_DIR=/tmp/server-profile \
#-- A valid git HTTPS URL (not ssh)
    SERVER_PROFILE_URL="" \
#-- When set to "true", the server profile git URL will not be printed to container output.
    SERVER_PROFILE_URL_REDACT=true \
#-- A valid git branch (optional)
    SERVER_PROFILE_BRANCH="" \
#-- The subdirectory in the git repo
    SERVER_PROFILE_PATH="" \
#-- Whether to update the server profile upon container restart
    SERVER_PROFILE_UPDATE="false" \

#-- Requires strict checks on security
    SECURITY_CHECKS_STRICT=false \
#-- Perform a check for filenames that may violate security (i.e. secret material)
    SECURITY_CHECKS_FILENAME="*.jwk *.pin" \

#-- If this is set to true, then the container will provide a hard warning and continue.
    UNSAFE_CONTINUE_ON_ERROR="" \
#-- License directory
    LICENSE_DIR="${SERVER_ROOT_DIR}" \
#-- PD License directory. Separating from above LICENSE_DIR to differentiate for different products
    PD_LICENSE_DIR="${STAGING_DIR}/pd.profile/server-root/pre-setup" \
#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="" \
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="" \
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
    STARTUP_BACKGROUND_OPTS="" \

    PING_IDENTITY_DEVOPS_KEY_REDACT=true \

#-- A whitespace separated list of log files to tail to the container
#-- standard output - DO NOT USE WILDCARDS like /path/to/logs/*.log
    TAIL_LOG_FILES="" \

#-- If 'true', the output logs will be colorized with GREENs and REDs,
#-- otherwise, no colorization will be done.  This is good for tools
#-- that monitor logs and colorization gets in the way.
    COLORIZE_LOGS=true \

#-- Location default value
    LOCATION=Docker \
    LOCATION_VALIDATION="true|Any string denoting a logical/physical location|Must be a string" \

#-- Heap size (for java products)
    MAX_HEAP_SIZE=384m \

    JVM_TUNING="AGGRESSIVE" \

#-- Percentage of the container memory to allocate to PingFederate JVM
#-- DO NOT set to 100% or your JVM will exit with OutOfMemory errors and the container will terminate
    JAVA_RAM_PERCENTAGE=75.0 \

#-- Triggers verbose messages in scripts using the set -x option.
    VERBOSE=false \

#-- Set the server in debug mode, with increased output
    PING_DEBUG=false \

#-- The name of Ping product.  Should be overridden by child images.
    PING_PRODUCT="" \
    PING_PRODUCT_VALIDATION="true|i.e. PingFederate,PingDirectory|Must be a valid Ping prouduct type" \

#-- List of setup arguments passed to Ping Data setup-arguments.txt file
    ADDITIONAL_SETUP_ARGS="" \

#-- Port over which to communicate for LDAP
    LDAP_PORT=1389 \
#-- Port over which to communicate for LDAPS
    LDAPS_PORT=1636 \
#-- Port over which to communicate for HTTPS
    HTTPS_PORT=1443 \
#-- Port for monitoring over JMX protocol
    JMX_PORT=1689 \

#-- The type of orchestration tool used to run the container, normally
#-- set in the deployment (.yaml) file.  Expected values include:
#-- - compose
#-- - swarm
#-- - kubernetes
#-- Defaults to blank (i.e. No type is set)
    ORCHESTRATION_TYPE="" \

#-- Base DN for user data
    USER_BASE_DN=dc=example,dc=com \
#-- Variable with a literal value of '$', to avoid unwanted variable substitution
    DOLLAR='$' \
#-- PD (PingDirectory) public hostname that may be used in redirects
    PD_ENGINE_PUBLIC_HOSTNAME="localhost" \
#-- PD (PingDirectory) private hostname
    PD_ENGINE_PRIVATE_HOSTNAME="pingdirectory" \
#-- PDP (PingDirectoryProxy) public hostname that may be used in redirects
    PDP_ENGINE_PUBLIC_HOSTNAME="localhost" \
#-- PDP (PingDirectoryProxy) private hostname
    PDP_ENGINE_PRIVATE_HOSTNAME="pingdirectoryproxy" \
#-- PDS (PingDataSync) public hostname that may be used in redirects
    PDS_ENGINE_PUBLIC_HOSTNAME="localhost" \
#-- PDS (PingDataSync) private hostname
    PDS_ENGINE_PRIVATE_HOSTNAME="pingdatasync" \
#-- PAZ (PingAuthorize) public hostname that may be used in redirects
    PAZ_ENGINE_PUBLIC_HOSTNAME="localhost" \
#-- PAZ (PingAuthorize) private hostname
    PAZ_ENGINE_PRIVATE_HOSTNAME="pingauthorize" \
#-- PAZP (PingAuthorize-PAP) public hostname that may be used in redirects
    PAZP_ENGINE_PUBLIC_HOSTNAME="localhost" \
#-- PAZP (PingAuthorize-PAP) private hostname
    PAZP_ENGINE_PRIVATE_HOSTNAME="pingauthorizepap" \
#-- PF (PingFederate) engine public hostname that may be used in redirects
    PF_ENGINE_PUBLIC_HOSTNAME="localhost" \
#-- PF (PingFederate) engine private hostname
    PF_ENGINE_PRIVATE_HOSTNAME="pingfederate" \
#-- PF (PingFederate) admin public baseurl that may be used in redirects
    PF_ADMIN_PUBLIC_BASEURL="https://localhost:9999" \
#-- PF (PingFederate) admin public hostname that may be used in redirects
    PF_ADMIN_PUBLIC_HOSTNAME="localhost" \
#-- PF (PingFederate) admin private hostname
    PF_ADMIN_PRIVATE_HOSTNAME="pingfederate-admin" \
#-- PA (PingAccess) engine public hostname that may be used in redirects
    PA_ENGINE_PUBLIC_HOSTNAME="localhost" \
#-- PA (PingAccess) engine private hostname
    PA_ENGINE_PRIVATE_HOSTNAME="pingaccess" \
#-- PA (PingAccess) admin public hostname that may be used in redirects
    PA_ADMIN_PUBLIC_HOSTNAME="localhost" \
#-- PA (PingAccess) admin private hostname
    PA_ADMIN_PRIVATE_HOSTNAME="pingaccess-admin" \
#-- DN of the server root user
    ROOT_USER_DN="cn=${ROOT_USER}" \
    ENV="${BASE}/.profile" \

#-- Instructs the image to pull the MOTD json from the following URL.
#-- If this MOTD_URL variable is empty, then no motd will be downloaded.
#-- The format of this MOTD file must match the example provided in the
#-- url: https://raw.githubusercontent.com/pingidentity/pingidentity-devops-getting-started/master/motd/motd.json
    MOTD_URL="https://raw.githubusercontent.com/pingidentity/pingidentity-devops-getting-started/master/motd/motd.json" \

#-- Default shell prompt (i.e. productName:hostname:workingDir)
    PS1="\${PING_PRODUCT}:\h:\w\n> " \

#-- PATH used by the container
    PATH="${JAVA_HOME}/bin:${BASE}:${SERVER_ROOT_DIR}/bin:${PATH}"

# VOLUME [ "${BAK_DIR}" "${IN_DIR}" "${OUT_DIR}" "${LOGS_DIR}" ]
WORKDIR ${BASE}

# Switch to the default non-root user created in build.sh
USER 9031:0

### WARNING THE ENTRYPOINT WILL NEED TO BE UPDATED MANUALLY IF THE BASE IS CHANGED
### IT DOES NOT EXPAND VARIABLES -- REAL BUMMER
### HOWEVER, AS LONG AS ENTRYPOINT IS NOT REFERENCED WITH AN ABSOLUTE PATH
### REBASING WILL WORK AS EXPECTED
ENTRYPOINT [ "./bootstrap.sh" ]
CMD [ "start-server" ]
