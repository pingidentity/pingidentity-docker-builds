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
# Legal requirement to explicitly accept the terms of the PingIdentity License
#-- Must be set to 'YES' for the container to start
ENV PING_IDENTITY_ACCEPT_EULA=NO

# the image base /might/ be changed at build-time but
# be aware that the entrypoint will have to be
# overridden to reflect the change
#-- Location of the top level directory where everything is located in
#-- image/container
ARG BASE
ENV BASE=${BASE:-/opt}
#-- Location of a local server-profile volume
ENV IN_DIR=${BASE}/in
#-- Path to the runtime volume
ENV OUT_DIR=${BASE}/out
#-- Path to the server bits
ENV SERVER_BITS_DIR=${BASE}/server
#-- Path to a volume generically used to export or backup data
ENV BAK_DIR=${BASE}/backup
#-- Path to a volume generically used for logging
ENV LOGS_DIR=${BASE}/logs

#-- File name for devops-creds passed as a Docker secret
ENV PING_IDENTITY_DEVOPS_FILE=devops-secret

#-- Path to the staging area where the remote and local server profiles
#-- can be merged
ENV STAGING_DIR=${BASE}/staging
#-- Path to a manifest of files expected in the staging dir on first image startup
ENV STAGING_MANIFEST=${BASE}/staging-manifest.txt
#-- Whether to clean the staging dir when the image starts
ENV CLEAN_STAGING_DIR=true
#-- Default path to the secrets
ENV SECRETS_DIR=/run/secrets
#-- Path to the topology file
ENV TOPOLOGY_FILE=${STAGING_DIR}/topology.json
#-- Path where all the hooks scripts are stored
ENV HOOKS_DIR=${STAGING_DIR}/hooks
#-- Environment Property file use to share variables between scripts in container
ENV CONTAINER_ENV=${STAGING_DIR}/.env

#-- Path where the remote server profile is checked out or cloned before
#-- being staged prior to being applied on the runtime
ENV SERVER_PROFILE_DIR=/tmp/server-profile
#-- A valid git HTTPS URL (not ssh)
ENV SERVER_PROFILE_URL=""
ENV SERVER_PROFILE_URL_REDACT=true
#-- A valid git branch (optional)
ENV SERVER_PROFILE_BRANCH=""
#-- The subdirectory in the git repo
ENV SERVER_PROFILE_PATH=""
#-- Whether to update the server profile upon container restart
ENV SERVER_PROFILE_UPDATE="false"
#-- Path from which the runtime executes
ENV SERVER_ROOT_DIR=${OUT_DIR}/instance

#-- Requires strict checks on security
ENV SECURITY_CHECKS_STRICT=false
#-- Perform a check for filenames that may violate security (i.e. secret material)
ENV SECURITY_CHECKS_FILENAME="*.jwk *.pin"

#-- If this is set to true, then the container will provide a hard warning and continue.
ENV UNSAFE_CONTINUE_ON_ERROR=""

#-- License directory and filename
ENV LICENSE_DIR="${SERVER_ROOT_DIR}"
#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
ENV STARTUP_COMMAND=""
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
ENV STARTUP_FOREGROUND_OPTS=""
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
ENV STARTUP_BACKGROUND_OPTS=""

ENV PING_IDENTITY_DEVOPS_KEY_REDACT=true

#-- A whitespace separated list of log files to tail to the container
#-- standard output - DO NOT USE WILDCARDS like /path/to/logs/*.log
ENV TAIL_LOG_FILES=""

#-- Set to true to use parallel for the invocation of the tail utility
ENV TAIL_LOG_PARALLEL=""

#-- If 'true', the output logs will be colorized with GREENs and REDs,
#-- otherwise, no colorization will be done.  This is good for tools
#-- that monitor logs and colorization gets in the way.
ENV COLORIZE_LOGS=true

#-- Location default value
ENV LOCATION=Docker
ENV LOCATION_VALIDATION="true|Any string denoting a logical/physical location|Must be a string"

#-- Heap size (for java products)
ENV MAX_HEAP_SIZE=384m

ENV JVM_TUNING="AGGRESSIVE"

#-- Triggers verbose messages in scripts using the set -x option.
ENV VERBOSE=false

#-- Set the server in debug mode, with increased output
ENV PING_DEBUG=false

#-- The name of Ping product.  Should be overridden by child images.
ENV PING_PRODUCT=""
ENV PING_PRODUCT_VALIDATION="true|i.e. PingFederate,PingDirectory|Must be a valid Ping prouduct type"

#-- List of setup arguments passed to Ping Data setup-arguments.txt file
ENV ADDITIONAL_SETUP_ARGS=""

#-- Port over which to communicate for LDAP
ENV LDAP_PORT=1389
#-- Port over which to communicate for LDAPS
ENV LDAPS_PORT=1636
#-- Port over which to communicate for HTTPS
ENV HTTPS_PORT=1443
#-- Port for monitoring over JMX protocol
ENV JMX_PORT=1689

#-- The type of orchestration tool used to run the container, normally
#-- set in the deployment (.yaml) file.  Expected values include:
#-- - compose
#-- - swarm
#-- - kubernetes
#-- Defaults to blank (i.e. No type is set)
ENV ORCHESTRATION_TYPE=""

ENV USER_BASE_DN=dc=example,dc=com
ENV DOLLAR='$'
#-- PD (PingDirectory) public hostname that may be used in redirects
ENV PD_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PD (PingDirectory) private hostname
ENV PD_ENGINE_PRIVATE_HOSTNAME="pingdirectory"
#-- PDP (PingDirectoryProxy) public hostname that may be used in redirects
ENV PDP_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PDP (PingDirectoryProxy) private hostname
ENV PDP_ENGINE_PRIVATE_HOSTNAME="pingdirectoryproxy"
#-- PDS (PingDataSync) public hostname that may be used in redirects
ENV PDS_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PDS (PingDataSync) private hostname
ENV PDS_ENGINE_PRIVATE_HOSTNAME="pingdatasync"
#-- PDG (PingDataGovernance) public hostname that may be used in redirects
ENV PDG_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PDG (PingDataGovernance) private hostname
ENV PDG_ENGINE_PRIVATE_HOSTNAME="pingdatagovernance"
#-- PDGP (PingDataGovernance-PAP) public hostname that may be used in redirects
ENV PDGP_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PDGP (PingDataGovernance-PAP) private hostname
ENV PDGP_ENGINE_PRIVATE_HOSTNAME="pingdatagovernancepap"
#-- PF (PingFederate) engine public hostname that may be used in redirects
ENV PF_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PF (PingFederate) engine private hostname
ENV PF_ENGINE_PRIVATE_HOSTNAME="pingfederate"
#-- PF (PingFederate) admin public hostname that may be used in redirects
ENV PF_ADMIN_PUBLIC_HOSTNAME="localhost"
#-- PF (PingFederate) admin private hostname
ENV PF_ADMIN_PRIVATE_HOSTNAME="pingfederate-admin"
#-- PA (PingAccess) engine prublic hostname that may be used in redirects
ENV PA_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PA (PingAccess) engine private hostname
ENV PA_ENGINE_PRIVATE_HOSTNAME="pingaccess"
#-- PA (PingAccess) admin public hostname that may be used in redirects
ENV PA_ADMIN_PUBLIC_HOSTNAME="localhost"
#-- PA (PingAccess) admin private hostname
ENV PA_ADMIN_PRIVATE_HOSTNAME="pingaccess-admin"

#-- the default administrative user for PingData
ENV ROOT_USER="administrator"
ENV ROOT_USER_DN="cn=${ROOT_USER}"


ENV ENV="${BASE}/.profile"

#-- Instructs the image to pull the MOTD json from the followig URL.
#-- If this MOTD_URL variable is empty, then no motd will be downloaded.
#-- The format of this MOTD file must match the example provided in the
#-- url: https://raw.githubusercontent.com/pingidentity/pingidentity-devops-getting-started/master/motd/motd.json
ENV MOTD_URL="https://raw.githubusercontent.com/pingidentity/pingidentity-devops-getting-started/master/motd/motd.json"

#-- Default shell prompt (i.e. productName:hostname:workingDir)
ENV PS1="\${PING_PRODUCT}:\h:\w\n> "

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

# VOLUME [ "${BAK_DIR}" "${IN_DIR}" "${OUT_DIR}" "${LOGS_DIR}" ]
WORKDIR ${BASE}

ENV JAVA_HOME=/opt/java

ENV PATH="${JAVA_HOME}/bin:${BASE}:${SERVER_ROOT_DIR}/bin:${PATH}"

# Switch to the default non-root user created in build.sh
USER 9031:9999

### WARNING THE ENTRYPOINT WILL NEED TO BE UPDATED MANUALLY IF THE BASE IS CHANGED
### IT DOES NOT EXPAND VARIABLES -- REAL BUMMER
### HOWEVER, AS LONG AS ENTRYPOINT IS NOT REFERENCED WITH AN ABSOLUTE PATH
### REBASING WILL WORK AS EXPECTED
ENTRYPOINT [ "./bootstrap.sh" ]
CMD [ "start-server" ]
