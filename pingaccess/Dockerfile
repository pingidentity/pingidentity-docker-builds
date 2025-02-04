#- # Ping Identity DevOps Docker Image - `pingaccess`
#-
#- This docker image includes the Ping Identity PingAccess product binaries
#- and associated hook scripts to create and run both PingAccess Admin and
#- Engine nodes.
#-
#- ## Related Docker Images
#-
#- - `pingidentity/pingbase` - Parent Image
#- > This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)
#- - `pingidentity/pingcommon` - Common Ping files (i.e. hook scripts)

#################################################################################

# Top level ARGS used in all FROM commands
ARG ARCH
ARG DEPS
ARG GIT_TAG
ARG JVM
ARG LATEST_ALPINE_VERSION
ARG REGISTRY
ARG SHIM
ARG SHIM_TAG

#################################################################################

FROM ${REGISTRY}/pingcommon:${GIT_TAG}-${ARCH} as common
FROM ${REGISTRY}/pingjvm:${JVM}-${SHIM_TAG}-${GIT_TAG}-${ARCH} as jvm

#################################################################################

# Always use alpine to download product bits
FROM ${DEPS}alpine:${LATEST_ALPINE_VERSION} as product-staging

# ARGS used in get-product-bits.sh RUN command
ARG ARTIFACTORY_URL
ARG PRODUCT
ARG SNAPSHOT_URL
ARG VERBOSE
ARG VERSION

# Get libxml2-utils for get-product-bits.sh
RUN apk --no-cache --update add libxml2-utils

# Get local filesystem product bits if present
COPY ["tmp/", "/tmp/"]

# Download the product bits
COPY --from=common ["/opt/get-product-bits.sh","/opt/get-product-bits.sh"]
RUN /opt/get-product-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip -q /tmp/product.zip -d /tmp/ \
        -x pingaccess-*/sdk/* \
        -x *.bat \
        -x *.dll \
        -x *.exe \
    && mv /tmp/pingaccess-* /opt/server

#################################################################################

FROM ${DEPS}${SHIM} as final-staging

# On PA 8.2 and later, need to use an updated run.sh file with extra CLASSPATH handling.
# TODO remove after deprecation of 8.1.x PA versions
ARG VERSION

# get the product bits FIRST
COPY --from=product-staging ["/opt/","/opt/"]

# get Ping-wide common scripts
#   this needs to happen after the bits have been laid down
#   so they can be patched
COPY --from=common ["/opt/","/opt/"]

# get the jvm
COPY --from=jvm ["/opt/java","/opt/java"]

# apply product-specific hooks and patches
COPY ["/opt","/opt"]

# add legal information in licenses directory
COPY --from=product-staging ["/opt/server/legal/","/licenses/"]

# Run build
RUN ["/opt/build.sh"]

#################################################################################

FROM ${REGISTRY}/pingbase:${GIT_TAG}-${ARCH} as base

# the final image
FROM ${DEPS}${SHIM}
# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
ARG DATE
ARG LICENSE_VERSION
ARG VERSION

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
#-- If PingDirectory is deployed in multi cluster mode, that is, 
#-- K8S_CLUSTER, K8S_CLUSTERS and K8S_SEED_CLUSTER are defined,
#-- LOCATION is ignored and K8S_CLUSTER is used as the location
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

#-- The name of Ping product, i.e. PingFederate, PingDirectory - must be a valid Ping product type.
#-- This variable should be overridden by child images. 
    PING_PRODUCT="" \
    PING_PRODUCT_VALIDATION="true|i.e. PingFederate,PingDirectory|Must be a valid Ping product type" \

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

# Embed license.txt in /license directory of container
COPY --from=final-staging "/licenses/" "/licenses/"
COPY --from=base "/licenses/" "/licenses/"

### WARNING THE ENTRYPOINT WILL NEED TO BE UPDATED MANUALLY IF THE BASE IS CHANGED
### IT DOES NOT EXPAND VARIABLES -- REAL BUMMER
### HOWEVER, AS LONG AS ENTRYPOINT IS NOT REFERENCED WITH AN ABSOLUTE PATH
### REBASING WILL WORK AS EXPECTED
ENTRYPOINT [ "./bootstrap.sh" ]
CMD [ "start-server" ]

ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
    DATE=${DATE} \
    PING_PRODUCT_VERSION=${VERSION} \
#-- Ping product name
    PING_PRODUCT="PingAccess" \
#-- License directory
    LICENSE_DIR="${SERVER_ROOT_DIR}/conf" \
#-- Name of license file
    LICENSE_FILE_NAME=pingaccess.lic \
#-- Short name used when retrieving license from License Server
    LICENSE_SHORT_NAME=PA \
#-- Version used when retrieving license from License Server
    LICENSE_VERSION=${LICENSE_VERSION} \
#-- PA_RUN_PA_OPERATIONAL_MODE will override this value for PingAccess 7.3 and later.
    OPERATIONAL_MODE="STANDALONE" \
    PA_ADMIN_PASSWORD_INITIAL="2Access" \
#-- Specify a password for administrator user for interaction with admin API
    PING_IDENTITY_PASSWORD="2FederateM0re" \
#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh" \
#-- Files tailed once container has started
    TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/pingaccess.log \
#-- Default port for PA Admin API and console
#-- Ignored when using PingIdentity Helm charts
    PA_ADMIN_PORT=9000 \
#-- Default port when clustering PA primary administrative node
#-- Ignored when using PingIdentity Helm charts
    PA_ADMIN_CLUSTER_PORT=9090 \
#-- Percentage of the container memory to allocate to PingAccess JVM
#-- DO NOT set to 100% or your JVM will exit with OutOfMemory errors and the container will terminate
    JAVA_RAM_PERCENTAGE=60.0 \
#-- Turns on FIPS mode (currently with the Bouncy Castle FIPS provider)
#-- set to exactly "true" lowercase to turn on
#-- set to anything else to turn off
#-- PA_FIPS_MODE_PA_FIPS_MODE will override this for PingAccess 7.3 and later.
    FIPS_MODE_ON=false \

#-- Defines a variable to allow showing library versions in the output at startup
#-- default to true
    SHOW_LIBS_VER="true" \

#-- Defines a variable to allow showing library version prior to patches being applied
#-- default to false
#-- This is helpful to ensure that the patch process updates all libraries affected
    SHOW_LIBS_VER_PRE_PATCH="false" \     

# pingaccess comes ootb listening on 3000 but it is more natural for https traffic to be listened for on 443
    PA_ENGINE_PORT=3000 \

#-- wait-for timeout for 80-post-start.sh hook script
#-- How long to wait for the PA Admin console to be available
    ADMIN_WAITFOR_TIMEOUT=300

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL name="${PING_PRODUCT}" \
      version="${IMAGE_VERSION}" \
      release="${IMAGE_GIT_REV}" \
      date="${DATE}" \
      summary="PingAccess is an identity-enabled access management product that protects web applications and APIs by applying security policies to client requests." \
      description="PingAccess allows you to protect sites, APIs, and other resources using rules and other authentication criteria. It works in conjunction with PingFederate or other common token providers with the OAuth 2.0 and OpenID Connect (OIDC) protocols to integrate identity-based access management policies through a federated corporate identity store using open standards access protocols." \
      maintainer="support@pingidentity.com" \
      license="Ping Identity Proprietary" \
      vendor="Ping Identity Corp." \
      io.k8s.description="PingAccess allows you to protect sites, APIs, and other resources using rules and other authentication criteria. It works in conjunction with PingFederate or other common token providers with the OAuth 2.0 and OpenID Connect (OIDC) protocols to integrate identity-based access management policies through a federated corporate identity store using open standards access protocols." \
      io.k8s.display-name="${PING_PRODUCT}" \
      url="https://www.pingidentity.com"

EXPOSE ${PA_ADMIN_PORT} ${PA_ENGINE_PORT} ${HTTPS_PORT}
COPY --from=final-staging ["/opt","/opt"]
COPY --from=final-staging ["/etc/motd","/etc/motd"]

# RUN ["/opt/build.sh"]
RUN ["/opt/install_deps.sh"]

# Switch to the default non-root user created in build.sh
USER 9031:0

#- ## Running a PingAccess container
#-
#- To run a PingAccess container:
#-
#- ```shell
#-   docker run \
#-            --name pingaccess \
#-            --publish 9000:9000 \
#-            --publish 443:1443 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingaccess \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingaccess:edge
#- ```
#-
#- Follow Docker logs with:
#-
#- ```
#- docker logs -f pingaccess
#- ```
#-
#- If using the command above with the embedded [server profile](https://devops.pingidentity.com/reference/config/), log in with:
#-
#- - https://localhost:9000
#-   - Username: Administrator
#-   - Password: 2FederateM0re
