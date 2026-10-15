#- # Ping Identity DevOps Docker Image - `pingdirectoryproxy`
#-
#- This docker image includes the Ping Identity PingDirectoryProxy product binaries
#- and associated hook scripts to create and run a PingDirectoryProxy instance or
#- instances.
#-
#- ## Related Docker Images
#- - `pingbase-java` (v2 base) - Parent Image
#- - `pingcommon`/`pingdatacommon` - Common Ping files (i.e. hook scripts)
#-

#################################################################################

# Top level ARGS used in all FROM commands
ARG ARCH
# Keep DEPS: the alpine product-staging stage downloads product bits through
# the deps pull-through registry.
ARG DEPS
# v2 base adoption: CI passes V2_BASE_IMAGE (+ JAVA_LINK for JVM
# products). Production CI fail-fasts on unmapped jvm ids before ever
# reaching here.
ARG V2_BASE_IMAGE
ARG JAVA_LINK

#################################################################################

# Always use alpine to download product bits (pinned here: the
# LATEST_ALPINE_VERSION build-arg was retired with the carrier-image
# mechanics in PDI-2523 — keep this pin in sync with build_foundation.sh
# and the alpine shim pins in the versions.json files).
FROM ${DEPS}alpine:3.24.2 AS product-staging

# ARGS used in get-product-bits.sh RUN command
ARG ARTIFACTORY_URL
ARG PRODUCT
ARG SNAPSHOT_URL
ARG VERBOSE
ARG VERSION

# Get libxml2-utils for get-product-bits.sh
RUN apk --no-cache --update add libxml2-utils

# Get Ping-wide common scripts from the build context (PDI-2523 carrier
# elimination: pingcommon/pingdatacommon are no longer built as images).
COPY ["pingcommon/opt/get-product-bits.sh","/opt/get-product-bits.sh"]

# Get local filesystem product bits if present
COPY ["pingdirectoryproxy/tmp/", "/tmp/"]

# Download the product bits
RUN /opt/get-product-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip -q /tmp/product.zip \
        -d /tmp/ \
    && mv /tmp/PingDirectoryProxy /opt/server

#################################################################################

FROM ${V2_BASE_IMAGE} AS final-staging

# v2 base images end at USER 9031:0; staging RUN steps run as root.
USER 0:0
# v2 alpine base ships tini at /sbin/tini (same path the ENTRYPOINT uses).
# Re-declared: top-level ARGs are not inherited into stage RUN scope.
ARG JAVA_LINK
# Preserve the JAVA_HOME=/opt/java contract (pingbase env + PATH); the link
# target lives inside the v2 base image.
RUN if test -n "${JAVA_LINK}"; then ln -s "${JAVA_LINK}" /opt/java; fi

# get the product bits FIRST
COPY --from=product-staging ["/opt/","/opt/"]

# get Ping-wide common scripts
#   this needs to happen after the bits have been laid down
#   so they can be patched
COPY ["pingcommon/opt/","/opt/"]
# get PingData-common scripts (layered on top of pingcommon)
COPY ["pingdatacommon/opt/","/opt/"]

# apply product-specific hooks and patches
COPY ["pingdirectoryproxy/opt","/opt"]

# add legal information in licenses directory
COPY --from=product-staging ["/opt/server/legal/","/licenses/"]

# Run build
RUN ["/opt/build.sh"]

#################################################################################

# The final image (v2 base — PDI-2523 final-stage unification; the v1
# pingbase env-carrier stage is retired, so the env vars it used to supply
# to the hook framework are re-declared below).
FROM ${V2_BASE_IMAGE}

# from pingbase
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

#-- Path to a manifest of files expected in the staging dir on first image startup
    STAGING_MANIFEST=${BASE}/staging-manifest.txt \
#-- Whether to clean the staging dir when the container starts
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
#-- The command-line options to provide to the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="" \
#-- The command-line options to provide to the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
    STARTUP_BACKGROUND_OPTS="" \

    PING_IDENTITY_DEVOPS_KEY_REDACT=true \

#-- Legal requirement to explicitly accept the terms of the PingIdentity License
#-- Must be set to 'YES' for the container to start
    PING_IDENTITY_ACCEPT_EULA=NO \
#-- File name for devops-creds passed as a Docker secret
    PING_IDENTITY_DEVOPS_FILE=devops-secret \

#-- A whitespace separated list of log files to tail to the container
#-- standard output - DO NOT USE WILDCARDS like /path/to/logs/*.log
    TAIL_LOG_FILES="" \

#-- If 'true', the output logs will be colorized with GREENs and REDs,
#-- otherwise, no colorization will be done.  This is good for tools
#-- that monitor logs and colorization gets in the way.
    COLORIZE_LOGS=true \

#-- Location default value
    LOCATION=Docker \
#-- Validation toggle for LOCATION: true to require any string denoting a
#-- logical/physical location, false to disable the check
    LOCATION_VALIDATION=true \

#-- Heap size (for java products)
    MAX_HEAP_SIZE=384m \

    JVM_TUNING="AGGRESSIVE" \

#-- Percentage of the container memory to allocate to the JVM
#-- DO NOT set to 100% or your JVM will exit with OutOfMemory errors and the container will terminate
    JAVA_RAM_PERCENTAGE=75.0 \

#-- Triggers verbose messages in scripts using the set -x option.
    VERBOSE=false \

#-- Set the server in debug mode, with increased output
    PING_DEBUG=false \

#-- The name of Ping product, i.e. PingFederate, PingDirectory - must be a valid Ping product type.
#-- This variable should be overridden by child images.
    PING_PRODUCT="" \
#-- Validation toggle for PING_PRODUCT: true to require a valid Ping product
#-- type (e.g. PingFederate,PingDirectory), false to disable the check
    PING_PRODUCT_VALIDATION=true \

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
#-- PF (PingFederate) admin public baseurl that may be used in redirects.
#-- PF_RUN_PF_ADMIN_BASEURL will override this value for PingFederate 11.3 and later.
    PF_ADMIN_PUBLIC_BASEURL="https://localhost:9999" \
#-- PF (PingFederate) admin public hostname that may be used in redirects.
#-- PF_RUN_PF_ADMIN_HOSTNAME will override this value for PingFederate 11.3 and later.
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

#-- Default shell prompt (i.e. productName:hostname:workingDir)
    PS1="\${PING_PRODUCT}:\h:\w\n> " \

#-- Whether to force a run of dsjavaproperties --initialize (false = only
#-- regenerate java.properties when the JVM or JVM options change)
    REGENERATE_JAVA_PROPERTIES=false \

#-- PATH used by the container
    PATH="${JAVA_HOME}/bin:${BASE}:${SERVER_ROOT_DIR}/bin:${PATH}"

# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
ARG DATE
ARG VERSION
# PingIdentity license version
ARG LICENSE_VERSION

ENV IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
    DATE=${DATE} \
    PING_PRODUCT_VERSION=${VERSION} \

#-- Ping product name
    PING_PRODUCT=PingDirectoryProxy \
#-- Name of license File
    LICENSE_FILE_NAME=PingDirectory.lic \
#-- PD License directory (staged PingData profile pre-setup, where the
#-- PD license is placed by the staging hooks)
    LICENSE_DIR="${PD_LICENSE_DIR}" \
#-- Short name used when retrieving license from License Server
    LICENSE_SHORT_NAME=PD \
#-- Version used when retrieving license from License Server
    LICENSE_VERSION=${LICENSE_VERSION} \

#-- Replication administrative user
    ADMIN_USER_NAME=admin \

#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server" \

#-- Public hostname of the DA app
    PD_DELEGATOR_PUBLIC_HOSTNAME=localhost \

#-- The command-line options to provide to the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="--nodetach" \

#-- The command-line options to provide to the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
    STARTUP_BACKGROUND_OPTS="" \

#-- Location of file with the root user password (i.e. cn=directory manager).
#-- Defaults to /SECRETS_DIR/root-user-password
    ROOT_USER_PASSWORD_FILE= \

#-- Location of the keystore file containing the server certificate.
#-- If left undefined, the SECRETS_DIR will be checked for a keystore.
#-- If that keystore does not exist, the server will generate a self-signed certificate.
    KEYSTORE_FILE= \
#-- Location of the pin file for the keystore defined in KEYSTORE_FILE.
#-- You must specify a KEYSTORE_PIN_FILE when a KEYSTORE_FILE is present.
#-- This value does not need to be defined when allowing the server to generate a
#-- self-signed certificate.
    KEYSTORE_PIN_FILE= \
#-- Format of the keystore defined in KEYSTORE_FILE. One of "jks", "pkcs12",
#-- "pem", or "bcfks" (in FIPS mode). If not defined, the keystore format will
#-- be inferred based on the file extension of the KEYSTORE_FILE, defaulting to "jks".
    KEYSTORE_TYPE= \
#-- Location of the truststore file for the server.
#-- If left undefined, the SECRETS_DIR will be checked for a truststore.
#-- If that truststore does not exist, the server will generate a truststore, containing
#-- its own certificate.
    TRUSTSTORE_FILE= \
#-- Location of the pin file for the truststore defined in TRUSTSTORE_FILE.
#-- You must specify a TRUSTSTORE_PIN_FILE when a TRUSTSTORE_FILE is present.
#-- This value does not need to be defined when allowing the server to generate a truststore.
    TRUSTSTORE_PIN_FILE= \
#-- Format of the truststore defined in TRUSTSTORE_FILE. One of "jks", "pkcs12",
#-- "pem", or "bcfks" (in FIPS mode). If not defined, the truststore format will
#-- be inferred based on the file extension of the TRUSTSTORE_FILE, defaulting to "jks".
    TRUSTSTORE_TYPE= \

#-- Files tailed once container has started
    TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/access ${SERVER_ROOT_DIR}/logs/errors ${SERVER_ROOT_DIR}/logs/failed-ops ${SERVER_ROOT_DIR}/logs/config-audit.log ${SERVER_ROOT_DIR}/logs/tools/*.log* ${SERVER_BITS_DIR}/logs/tools/*.log*" \

#-- Directory for the profile used by the PingData manage-profile tool
    PD_PROFILE="${STAGING_DIR}/pd.profile" \

#-- Setting this variable to true speeds up server startup time by
#-- skipping an unnecessary JVM check.
    UNBOUNDID_SKIP_START_PRECHECK_NODETACH=true \

#-- There is an additional certificate-based variable used to identity the certificate alias 
#-- used within the `KEYSTORE_FILE`. That variable is called `CERTIFICATE_NICKNAME`,
#-- which identifies the certificate to use by the server in the `KEYSTORE_FILE`. 
#-- If a value is not provided, the container will look at the list certs found in the 
#-- `KEYSTORE_FILE` and if one - and only one - certificate is found of type `PrivateKeyEntry`,
#-- that alias will be used.
    CERTIFICATE_NICKNAME= \

#-- The default retry timeout in seconds for manage-topology and
#-- remove-defunct-server
    RETRY_TIMEOUT_SECONDS=180 \

#-- Set this variable to configure Proxy for automatic server discovery with PingDirectory hostname
#-- JOIN_PD_TOPOLOGY must be enabled for PINGDIRECTORY_HOSTNAME to take effect
    PINGDIRECTORY_HOSTNAME="" \

#-- Set this variable to configure Proxy for automatic server discovery with PingDirectory LDAPS port
#-- JOIN_PD_TOPOLOGY must be enabled for PINGDIRECTORY_LDAPS_PORT to take effect
    PINGDIRECTORY_LDAPS_PORT="" \

#-- Setting this variable to true will configure proxy to join the topology of PingDirectory
    JOIN_PD_TOPOLOGY=false \

#-- Sets the number of columns in PingDirectoryProxy command-line tool output
    COLUMNS=120

# WORKDIR parity with the v1 env-carrier (WORKDIR /opt): the v2 base sets /
# (PDI-2523 unification). ENTRYPOINT below is absolute either way, but
# exec/interactive sessions kept the /opt default (PF precedent).
WORKDIR ${BASE}

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL name="${PING_PRODUCT}" \
      version="${IMAGE_VERSION}" \
      release="${IMAGE_GIT_REV}" \
      date="${DATE}" \
      summary="The PingDirectoryProxy server is a LDAP proxy server for PingDirectory that provides high availability and additional security." \
      description="The PingDirectoryProxy server is a fast, scalable, and easy-to-use LDAP proxy server that provides high availability and additional security for the PingDirectory server while remaining largely invisible to client applications. From a client perspective, request processing is the same, whether communicating with the PingDirectory server directly or going through the PingDirectoryProxy server."

EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT}

# Explicit entrypoint chain (PDI-2523 unification): the v1 pingbase
# env-carrier stage used to supply `ENTRYPOINT ["./bootstrap.sh"]`. Absolute
# paths — the v2 base's WORKDIR is /, not /opt. /sbin/tini (0.19.0) ships in
# the v2 base itself.
ENTRYPOINT ["/sbin/tini", "--", "/opt/bootstrap.sh"]
CMD ["start-server"]

# Legal pointer (was shipped by the v1 pingbase carrier as /licenses/license.txt;
# re-homed to the build context for the v2 base, which ships no /licenses).
COPY ["pingbase/license.txt", "/licenses/license.txt"]

COPY --from=final-staging ["/","/"]

#- ## Running a PingDirectoryProxy container
#-
#- The easiest way to test a simple standalone image of PingDirectoryProxy is to cut/paste the following command into a terminal on a machine with docker.
#-
#- ```
#-   docker run \
#-            --name pingdirectoryproxy \
#-            --publish 1389:1389 \
#-            --publish 8443:1443 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=baseline/pingdirectoryproxy \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingdirectoryproxy:edge
#- ```
#-
#- You can view the Docker logs with the command:
#-
#- ```
#-   docker logs -f pingdirectoryproxy
#- ```
#-
#- You should see the output from a PingDirectoryProxy install and configuration, ending with a message the PingDirectoryProxy has started.  After it starts, you will see some typical access logs.  Simply ``Ctrl-C`` after to stop tailing the logs.
#-
#- ## Running a sample 100/sec search rate test
#- With the PingDirectoryProxy running from the previous section, you can run a ``searchrate`` job that will send load to the directory at a rate of 100/sec using the following command.
#-
#- ```
#- docker exec -it pingdirectoryproxy \
#-         /opt/out/instance/bin/searchrate \
#-                 -b dc=example,dc=com \
#-                 --scope sub \
#-                 --filter "(uid=user.[1-9])" \
#-                 --attribute mail \
#-                 --numThreads 2 \
#-                 --ratePerSecond 100
#- ```
#-
#- ## Connecting with an LDAP Client
#- Connect an LDAP Client (such as Apache Directory Studio) to this container using the default ports and credentials
#-
#- |                 |                                   |
#- | --------------: | --------------------------------- |
#- | LDAP Port       | 1389                              |
#- | LDAP Base DN    | dc=example,dc=com                 |
#- | Root Username   | cn=administrator                  |
#- | Root Password   | 2FederateM0re                     |
#-
#- ## Stopping/Removing the container
#- To stop the container:
#-
#- ```
#-   docker container stop pingdirectoryproxy
#- ```
#-
#- To remove the container:
#-
#- ```
#-   docker container rm -f pingdirectoryproxy
#- ```
