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
#-- Image version, set by build process of the docker build
ONBUILD ARG IMAGE_VERSION="unspecified"
ONBUILD ENV IMAGE_VERSION=${IMAGE_VERSION}

#-- Image git revision, set by build process of the docker build
ONBUILD ARG IMAGE_GIT_REV=""
ONBUILD ENV IMAGE_GIT_REV=${IMAGE_GIT_REV}

ONBUILD LABEL	image-version="${IMAGE_VERSION}" \
                image-git-rev="${IMAGE_GIT_REV}"

# Legal requirement to explicitly accept the terms of the PingIdentity License
#-- Must be set to 'YES' for the container to start
ONBUILD ENV ACCEPT_EULA=NO

# the image base /might/ be changed at build-time but
# be aware that the entrypoint will have to be
# overridden to reflect the change
#-- Location of the top level directory where everything is located in 
#-- image/container
ONBUILD ARG BASE
ONBUILD ENV BASE=${BASE:-/opt}
#-- Location of a local server-profile volume
ONBUILD ENV IN_DIR=${BASE}/in
#-- Path to the runtime volume
ONBUILD ENV OUT_DIR=${BASE}/out
#-- Path to the server bits
ONBUILD ENV SERVER_BITS_DIR=${BASE}/server
#-- Path to a volume generically used to export or backup data
ONBUILD ENV BAK_DIR=${BASE}/backup
#-- Path to a volume generically used for logging
ONBUILD ENV LOGS_DIR=${BASE}/logs

#-- File name for devops-creds passed as a Docker secret
ONBUILD ENV PING_IDENTITY_DEVOPS_FILE=devops-secret

#-- Path to the staging area where the remote and local server profiles
#-- can be merged
ONBUILD ENV STAGING_DIR=${BASE}/staging
#-- Default path to the secrets
ONBUILD ENV SECRETS_DIR=${STAGING_DIR}/.sec
#-- Path to the topology file
ONBUILD ENV TOPOLOGY_FILE=${STAGING_DIR}/topology.json
#-- Path where all the hooks scripts are stored
ONBUILD ENV HOOKS_DIR=${STAGING_DIR}/hooks
#-- Environment Property file use to share variables between scripts in container
ONBUILD ENV CONTAINER_ENV=${STAGING_DIR}/.env

#-- Path where the remote server profile is checked out or cloned before
#-- being staged prior to being applied on the runtime
ONBUILD ENV SERVER_PROFILE_DIR=/tmp/server-profile
#-- A valid git HTTPS URL (not ssh)
ONBUILD ENV SERVER_PROFILE_URL=""
ONBUILD ENV SERVER_PROFILE_URL_REDACT=true
#-- A valid git branch (optional)
ONBUILD ENV SERVER_PROFILE_BRANCH=""
#-- The subdirectory in the git repo
ONBUILD ENV SERVER_PROFILE_PATH=""
#-- Whether to update the server profile upon container restart
ONBUILD ENV SERVER_PROFILE_UPDATE="false"
#-- Path from which the runtime executes
ONBUILD ENV SERVER_ROOT_DIR=${OUT_DIR}/instance

#-- Requires strict checks on security
ONBUILD ENV SECURITY_CHECKS_STRICT=false
#-- Perform a check for filenames that may violate security (i.e. secret material)
ONBUILD ENV SECURITY_CHECKS_FILENAME="*.jwk *.pin"

#-- License directory and filename
ONBUILD ENV LICENSE_DIR="${SERVER_ROOT_DIR}"
#-- The command that the entrypoint will execute in the foreground to 
#-- instantiate the container
ONBUILD ENV STARTUP_COMMAND=""
#-- The command-line options to provide to the the startup command when 
#-- the container starts with the server in the foreground. This is the 
#-- normal start flow for the container
ONBUILD ENV STARTUP_FOREGROUND_OPTS=""
#-- The command-line options to provide to the the startup command when 
#-- the container starts with the server in the background. This is the 
#-- debug start flow for the container
ONBUILD ENV STARTUP_BACKGROUND_OPTS=""

ONBUILD ENV PING_IDENTITY_DEVOPS_KEY_REDACT=true

#-- A whitespace separated list of log files to tail to the container 
#-- standard output
ONBUILD ENV TAIL_LOG_FILES=""

#-- If 'true', the output logs will be colorized with GREENs and REDs,
#-- otherwise, no colorization will be done.  This is good for tools
#-- that monitor logs and colorization gets in the way.
ONBUILD ENV COLORIZE_LOGS=true

#-- Location default value
ONBUILD ENV LOCATION=Docker
ONBUILD ENV LOCATION_VALIDATION="true|Any string denoting a logical/physical location|Must be a string"

#-- Heap size (for java products)
ONBUILD ENV MAX_HEAP_SIZE=384m

ONBUILD ENV JVM_TUNING="AGGRESSIVE"

#-- Triggers verbose messages in scripts using the set -x option.
ONBUILD ENV VERBOSE=false

#-- Set the server in debug mode, with increased output
ONBUILD ENV PING_DEBUG=false

#-- The name of Ping product.  Should be overridden by child images.
ONBUILD ENV PING_PRODUCT=""
ONBUILD ENV PING_PRODUCT_VALIDATION="true|i.e. PingFederate,PingDirectory|Must be a valid Ping prouduct type"

#-- List of setup arguments passed to Ping Data setup-arguments.txt file
ONBUILD ENV ADDITIONAL_SETUP_ARGS=""

#-- Port over which to communicate for LDAP
ONBUILD ENV LDAP_PORT=389
#-- Port over which to communicate for LDAPS
ONBUILD ENV LDAPS_PORT=636
#-- Port over which to communicate for HTTPS
ONBUILD ENV HTTPS_PORT=443
#-- Port for monitoring over JMX protocol
ONBUILD ENV JMX_PORT=689

#-- The type of orchestration tool used to run the container, normally
#-- set in the deployment (.yaml) file.  Expected values include:
#-- - compose
#-- - swarm
#-- - kubernetes
#-- Defaults to blank (i.e. No type is set)
ONBUILD ENV ORCHESTRATION_TYPE=""

ONBUILD ENV USER_BASE_DN=dc=example,dc=com
ONBUILD ENV DOLLAR='$'
#-- PD (PingDirectory) public hostname that may be used in redirects
ONBUILD ENV PD_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PD (PingDirectory) private hostname
ONBUILD ENV PD_ENGINE_PRIVATE_HOSTNAME="pingdirectory"
#-- PDP (PingDirectoryProxy) public hostname that may be used in redirects
ONBUILD ENV PDP_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PDP (PingDirectoryProxy) private hostname
ONBUILD ENV PDP_ENGINE_PRIVATE_HOSTNAME="pingdirectoryproxy"
#-- PDS (PingDataSync) public hostname that may be used in redirects
ONBUILD ENV PDS_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PDS (PingDataSync) private hostname
ONBUILD ENV PDS_ENGINE_PRIVATE_HOSTNAME="pingdatasync"
#-- PDG (PingDataGovernance) public hostname that may be used in redirects
ONBUILD ENV PDG_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PDG (PingDataGovernance) private hostname
ONBUILD ENV PDG_ENGINE_PRIVATE_HOSTNAME="pingdatagovernance"
#-- PDGP (PingDataGovernance-PAP) public hostname that may be used in redirects
ONBUILD ENV PDGP_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PDGP (PingDataGovernance-PAP) private hostname
ONBUILD ENV PDGP_ENGINE_PRIVATE_HOSTNAME="pingdatagovernancepap"
#-- PF (PingFederate) engine public hostname that may be used in redirects
ONBUILD ENV PF_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PF (PingFederate) engine private hostname
ONBUILD ENV PF_ENGINE_PRIVATE_HOSTNAME="pingfederate"
#-- PF (PingFederate) admin public hostname that may be used in redirects
ONBUILD ENV PF_ADMIN_PUBLIC_HOSTNAME="localhost"
#-- PF (PingFederate) admin private hostname
ONBUILD ENV PF_ADMIN_PRIVATE_HOSTNAME="pingfederate-admin"
#-- PA (PingAccess) engine prublic hostname that may be used in redirects
ONBUILD ENV PA_ENGINE_PUBLIC_HOSTNAME="localhost"
#-- PA (PingAccess) engine private hostname
ONBUILD ENV PA_ENGINE_PRIVATE_HOSTNAME="pingaccess"
#-- PA (PingAccess) admin public hostname that may be used in redirects
ONBUILD ENV PA_ADMIN_PUBLIC_HOSTNAME="localhost"
#-- PA (PingAccess) admin private hostname
ONBUILD ENV PA_ADMIN_PRIVATE_HOSTNAME="pingaccess-admin"

#-- the default administrative user for PingData
ONBUILD ENV ROOT_USER="administrator"
ONBUILD ENV ROOT_USER_DN="cn=${ROOT_USER}"


ONBUILD ENV ENV="${BASE}/.profile"

#-- Instructs the image to pull the MOTD json from the followig URL.
#-- If this MOTD_URL variable is empty, then no motd will be downloaded.
#-- The format of this MOTD file must match the example provided in the
#-- url: https://raw.githubusercontent.com/pingidentity/pingidentity-devops-getting-started/master/motd/motd.json
ONBUILD ENV MOTD_URL="https://raw.githubusercontent.com/pingidentity/pingidentity-devops-getting-started/master/motd/motd.json"

#-- Default shell prompt (i.e. productName:hostname:workingDir)
ONBUILD ENV PS1="\${PING_PRODUCT}:\h:\w\n> "

# the method by which the framework can assess whether the container is viable or not
ONBUILD HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

# ONBUILD VOLUME [ "${BAK_DIR}" "${IN_DIR}" "${OUT_DIR}" "${LOGS_DIR}" ]
ONBUILD WORKDIR ${BASE}

#-- Whether to run the process as Root or not
#-- if set to false, user spec can be left to default (uid:9031, gid:9999)
#-- or a custom uid can be passed with PING_CONTAINER_UID
#-- and PING_CONTAINER_GID
ONBUILD ENV PING_CONTAINER_PRIVILEGED="true"

#-- The user ID the product will use if PING_CONTAINER_PRIVILEGED is set to false
ONBUILD ENV PING_CONTAINER_UID=9031
#-- The group ID the product will use if PING_CONTAINER_PRIVILEGED is set to false
ONBUILD ENV PING_CONTAINER_GID=9999
#-- The user name the product will use if PING_CONTAINER_PRIVILEGED is set to false and a user with that ID does not exist already
ONBUILD ENV PING_CONTAINER_UNAME=ping
#-- The group name the product will use if PING_CONTAINER_PRIVILEGED is set to false and a group with that ID does not exist already
ONBUILD ENV PING_CONTAINER_GNAME=identity

ONBUILD ENV JAVA_HOME=/opt/java

ONBUILD ENV PATH="${JAVA_HOME}/bin:${BASE}:${SERVER_ROOT_DIR}/bin:${PATH}"

### WARNING THE ENTRYPOINT WILL NEED TO BE UPDATED MANUALLY IF THE BASE IS CHANGED
### IT DOES NOT EXPAND VARIABLES -- REAL BUMMER
### HOWEVER, AS LONG AS ENTRYPOINT IS NOT REFERENCED WITH AN ABSOLUTE PATH
### REBASING WILL WORK AS EXPECTED
ONBUILD ENTRYPOINT [ "./bootstrap.sh" ]
ONBUILD CMD [ "start-server" ]
