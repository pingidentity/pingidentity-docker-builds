#- # Ping Identity DevOps Docker Image - `pingfederate`
#-
#- This docker image includes the Ping Identity PingFederate product binaries
#- and associated hook scripts to create and run both PingFederate Admin and
#- Engine nodes.
#-
#- ## Related Docker Images
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

# Get local filesystem product bits if present
COPY ["tmp/", "/tmp/"]

# Download the product bits
# TODO Remove the `-x` options in the unzip commands after PF 11.2 GA and use of min zip files.
COPY --from=common ["/opt/get-product-bits.sh","/opt/get-product-bits.sh"]
RUN /opt/get-product-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip -q /tmp/product.zip -d /tmp/ \
        -x */pingfederate-service-installer.jar \
        -x pingfederate-*/pingfederate/sdk/* \
        -x *.bat \
        -x *.dll \
        -x *.exe \
    && mv /tmp/${PRODUCT}-*/${PRODUCT} /opt/server \
    && mkdir -p /opt/out/instance/server/default/data

#################################################################################

FROM ${DEPS}${SHIM} as final-staging

# On PF 12.2 and later, use the run.sh packaged with the product,
# else use the custom run.sh file
# TODO remove after deprecation of 12.1.x PF versions
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

# The final image
FROM ${DEPS}${SHIM}

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

#-- Instructs the image to pull the MOTD json from the following URL.
#-- If this MOTD_URL variable is empty, then no motd will be downloaded.
#-- The format of this MOTD file must match the example provided in the
#-- url: https://raw.githubusercontent.com/pingidentity/pingidentity-devops-getting-started/master/motd/motd.json
    MOTD_URL="https://raw.githubusercontent.com/pingidentity/pingidentity-devops-getting-started/master/motd/motd.json" \

#-- Default shell prompt (i.e. productName:hostname:workingDir)
    PS1="\${PING_PRODUCT}:\h:\w\n> " \

#-- PATH used by the container
    PATH="${JAVA_HOME}/bin:${BASE}:${SERVER_ROOT_DIR}/bin:${PATH}"

# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
ARG DATE
ARG VERSION
ARG LICENSE_VERSION

ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
    DATE=${DATE} \
    PING_PRODUCT_VERSION=${VERSION} \
#-- Ping product name
    PING_PRODUCT="PingFederate" \
#-- License directory
    LICENSE_DIR="${SERVER_ROOT_DIR}/server/default/conf" \
#-- Name of license file
    LICENSE_FILE_NAME="pingfederate.lic" \
#-- Short name used when retrieving license from License Server
    LICENSE_SHORT_NAME="PF" \
#-- Version used when retrieving license from License Server
    LICENSE_VERSION=${LICENSE_VERSION} \
#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh" \
#-- Specify a password for administrator user for interaction with admin API
    PING_IDENTITY_PASSWORD="2FederateM0re" \
#-- Files tailed once container has started
    TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/server.log \

#-- Defines the log file size max for ALL appenders
    PF_LOG_SIZE_MAX="10000 KB" \

#-- Defines the maximum of log files to retain upon rotation
    PF_LOG_NUMBER=2 \

#-- Defines the port on which the PingFederate administrative
#-- console and API runs.
#-- PF_RUN_PF_ADMIN_HTTPS_PORT will override this for PingFederate 11.3 and later.
    PF_ADMIN_PORT=9999 \

#-- Defines the port on which PingFederate listens for
#-- encrypted HTTPS (SSL/TLS) traffic.
#-- PF_RUN_PF_HTTPS_PORT will override this for PingFederate 11.3 and later.
    PF_ENGINE_PORT=9031 \

#-- Defines a secondary HTTPS port that can be used for mutual SSL/TLS 
#-- (client X.509 certificate) authentication for both end users and protocol requests.
#-- PF_RUN_PF_SECONDARY_HTTPS_PORT (default 9032) will override this value.
#-- The default value of -1 disables the port in the product.
    PF_ENGINE_SECONDARY_PORT=-1 \

#-- Flag to turn on PingFederate Engine debugging
#-- Used in run.sh
    PF_ENGINE_DEBUG=false \

#-- Flag to turn on PingFederate Admin debugging
#-- Used in run.sh
    PF_ADMIN_DEBUG=false \

#-- Defines the port on which PingFederate opens up a java debugging port.
#-- Used in run.sh
    PF_DEBUG_PORT=9030 \

#-- Defines a variable to allow showing library versions in the output at startup
#-- default to true
    SHOW_LIBS_VER="true" \

#-- Defines a variable to allow showing library version prior to patches being applied
#-- default to false
#-- This is helpful to ensure that the patch process updates all libraries affected
    SHOW_LIBS_VER_PRE_PATCH="false" \ 

#-- Operational Mode
#-- Indicates the operational mode of the runtime server in run.properties
#-- Options include STANDALONE, CLUSTERED_CONSOLE, CLUSTERED_ENGINE.
#-- PF_RUN_PF_OPERATIONAL_MODE will override this for PingFederate 11.3 and later.
    OPERATIONAL_MODE="STANDALONE" \

#-- Defines mechanism for console authentication in run.properties.
#-- Options include none, native, LDAP, cert, RADIUS, OIDC.
#-- If not set, default is native.
#-- PF_RUN_PF_CONSOLE_AUTHENTICATION will override this for PingFederate 11.3 and later.
    PF_CONSOLE_AUTHENTICATION= \

#-- Defines mechanism for admin api authentication in run.properties.
#-- Options include none, native, LDAP, cert, RADIUS, OIDC.
#-- If not set, default is native.
#-- PF_RUN_PF_ADMIN_API_AUTHENTICATION will override this for PingFederate 11.3 and later.
    PF_ADMIN_API_AUTHENTICATION= \

#-- Hardware Security Module Mode in run.properties
#-- Options include OFF, AWSCLOUDHSM, NCIPHER, LUNA, BCFIPS.
#-- PF_RUN_PF_HSM_MODE will override this for PingFederate 11.3 and later.
    HSM_MODE="OFF" \

#-- Defines a variable that allows instantiating non-FIPS crypto/random
    PF_BC_FIPS_APPROVED_ONLY=false \

#-- Hardware Security Module Hybrid Mode
#--   When PF is in Hybrid mode, certs/keys can be created either on the local trust store or on the HSM.
#--   This can used as a migration strategy towards an HSM setup.
#-- PF_RUN_PF_HSM_HYBRID will override this for PingFederate 11.3 and later.
    PF_HSM_HYBRID=false \

#-- This is the type of the LDAP directory server. This property is needed by
#-- PingFederate to determine how to handle different implementations between
#-- the available LDAP directory server types. Valid options include: ActiveDirectory,
#-- SunDirectoryServer, OracleUnifiedDirectory, PingDirectory, and Generic.
    PF_LDAP_TYPE=PingDirectory \

#-- This is the username for an account within the LDAP Directory Server
#-- that can be used to perform user lookups for authentication and other
#-- user level search operations.  Set if PF_CONSOLE_AUTHENTICATION or
#-- PF_ADMIN_API_AUTHENTICATION=LDAP
#-- PF_LDAP_LDAP_USERNAME will override this for PingFederate 11.3 and later.
    PF_LDAP_USERNAME="" \

#-- This is the password for the Username specified above.
#-- This property should be obfuscated using the 'obfuscate.sh' utility.
#-- Set if PF_CONSOLE_AUTHENTICATION or PF_ADMIN_API_AUTHENTICATION=LDAP
#-- PF_LDAP_LDAP_PASSWORD will override this for PingFederate 11.3 and later.
    PF_LDAP_PASSWORD="" \

#-- IP address for cluster communication.  Set to NON_LOOPBACK to
#-- allow the system to choose an available non-loopback IP address.
#-- PF_RUN_PF_CLUSTER_BIND_ADDRESS will override this for PingFederate 11.3 and later.
    CLUSTER_BIND_ADDRESS="NON_LOOPBACK" \

#-- Provisioner Mode in run.properties
#-- Options include OFF, STANDALONE, FAILOVER.
#-- PF_RUN_PF_PROVISIONER_MODE will override this for PingFederate 11.3 and later.
    PF_PROVISIONER_MODE=OFF \

#-- Provisioner Node ID in run.properties
#-- Initial active provisioning server node ID is 1
#-- PF_RUN_PROVISIONER_NODE_ID will override this for PingFederate 11.3 and later.
    PF_PROVISIONER_NODE_ID=1 \

#-- Node group ID in cluster-adaptive.conf file. Does not require a .subst file.
#    PF_CLUSTER_ADAPTIVE_NODE_GROUP_ID= \

#-- Provisioner Failover Grace Period in run.properties
#-- Grace period, in seconds. Default 600 seconds
#-- PF_RUN_PROVISIONER_FAILOVER_GRACE_PERIOD will override this for PingFederate 11.3 and later.
    PF_PROVISIONER_GRACE_PERIOD=600 \

#-- Override the default value for the minimum size of the Jetty thread pool
#-- Leave unset to let the container automatically tune the value according to available resources
#-- PF_RUN_PF_RUNTIME_THREADS_MIN will override this for PingFederate 11.3 and later.
    PF_JETTY_THREADS_MIN="" \

#-- Override the default value for the maximum size of the Jetty thread pool
#-- Leave unset to let the container automatically tune the value according to available resources
#-- PF_RUN_PF_RUNTIME_THREADS_MAX will override this for PingFederate 11.3 and later.
    PF_JETTY_THREADS_MAX="" \

#-- The size of the accept queue. There is generally no reason to tune this but please refer
#-- to the performance tuning guide for further tuning guidance.
#-- PF_RUN_PF_RUNTIME_ACCEPTQUEUESIZE will override this for PingFederate 11.3 and later.
    PF_ACCEPT_QUEUE_SIZE=512 \

#-- The region of the PingOne tenant PingFederate should connect with.
#-- Valid values are "com", "eu" and "asia"
#-- PF_RUN_PF_PINGONE_ADMIN_URL_REGION will override this for PingFederate 11.3 and later.
    PF_PINGONE_REGION="" \

#-- The PingOne environment ID to use
#-- PF_RUN_PF_PINGONE_ADMIN_URL_ENVIRONMENT_ID will override this for PingFederate 11.3 and later.
    PF_PINGONE_ENV_ID="" \

#-- The title featured in the administration console -- this is generally used to easily distinguish between environments
#-- PF_RUN_PF_CONSOLE_TITLE will override this for PingFederate 11.3 and later.
    PF_CONSOLE_TITLE="Docker PingFederate" \

#-- This property defines the tags associated with this PingFederate node.
#-- Configuration is optional. When configured, PingFederate takes this property
#-- into consideration when processing requests. For example, tags may be used
#-- to determine the data store location that this PingFederate
#-- node communicates with. Administrators may also use tags in conjunction with
#-- authentication selectors and policies to define authentication requirements.
#--
#-- Administrators may define one tag or a list of space-separated tags.
#-- Each tag cannot contain any spaces. Other characters are allowed.
#--
#-- Example 1: PF_NODE_TAGS=north
#-- Example 1 defines one tag: 'north'
#
#-- Example 2: PF_NODE_TAGS=1 123 test
#-- Example 2 defines three tags: '1', '123' and 'test'
#--
#-- Example 3: PF_NODE_TAGS=
#-- Example 3 is also valid because the PF_NODE_TAGS property is optional.
#-- PF_RUN_NODE_TAGS will override this for PingFederate 11.3 and later.
    PF_NODE_TAGS="" \

#-- This property defines the name of the PingFederate environment that will be
#-- displayed in the administrative console, used to make separate environments
#-- easily identifiable.
#-- PF_RUN_PF_CONSOLE_ENVIRONMENT will override this for PingFederate 11.3 and later.
    PF_CONSOLE_ENV="" \

#-- Percentage of the container memory to allocate to PingFederate JVM
#-- DO NOT set to 100% or your JVM will exit with OutOfMemory errors and the container will terminate
    JAVA_RAM_PERCENTAGE=75.0 \

    BULK_CONFIG_DIR="${OUT_DIR}/instance/bulk-config" \
    BULK_CONFIG_FILE=data.json \

#-- wait-for timeout for 80-post-start.sh hook script
#-- How long to wait for the PF Admin console to be available
    ADMIN_WAITFOR_TIMEOUT=300 \

#-- Set to true to create the initial admin user after PingFederate starts up.
#-- The initial admin user will only be created on the first startup of the server after the license is accepted.
    CREATE_INITIAL_ADMIN_USER=false \

#-- Set to true to add the following Java flags and enable memory dumps
#-- -XX:+HeapDumpOnOutOfMemoryError
#-- -XX:HeapDumpPath=$PF_HOME_ESC/log"
    ENABLE_AUTOMATIC_HEAP_DUMP=true

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL name="${PING_PRODUCT}" \
      version="${IMAGE_VERSION}" \
      release="${IMAGE_GIT_REV}" \
      date="${DATE}" \
      summary="PingFederate is an enterprise federation server and identity bridge for user authentication and standards-based single sign-on (SSO) for employee, partner, and customer identity types." \
      description="PingFederate enables outbound and inbound solutions for SSO, federated identity management, customer identity and access management, mobile identity security, API security, and social identity integration. Browser-based SSO extends employee, customer, and partner identities across domains without passwords using standard identity protocols, such as SAML, WS-Federation, WS-Trust, OAuth, OpenID Connect (OIDC), and System for Cross-domain Identity Management (SCIM)." \
      maintainer="support@pingidentity.com" \
      license="Ping Identity Proprietary" \
      vendor="Ping Identity Corp." \
      io.k8s.description="PingFederate enables outbound and inbound solutions for SSO, federated identity management, customer identity and access management, mobile identity security, API security, and social identity integration. Browser-based SSO extends employee, customer, and partner identities across domains without passwords using standard identity protocols, such as SAML, WS-Federation, WS-Trust, OAuth, OpenID Connect (OIDC), and System for Cross-domain Identity Management (SCIM)." \
      io.k8s.display-name="${PING_PRODUCT}" \
      url="https://www.pingidentity.com"

EXPOSE 9031 9999

WORKDIR ${BASE}

ENTRYPOINT [ "./bootstrap.sh" ]
CMD [ "start-server" ]

COPY --from=final-staging "/licenses/" "/licenses/"
COPY --from=base "/licenses/" "/licenses/"

# get the staged bits
COPY --from=final-staging ["/opt","/opt"]
COPY --from=final-staging ["/etc/motd","/etc/motd"]

RUN ["/opt/install_deps.sh"]

# Switch to the default non-root user created in build.sh
USER 9031:0

#- ## Running a PingFederate container
#- To run a PingFederate container:
#-
#- ```shell
#-   docker run \
#-            --name pingfederate \
#-            --publish 9999:9999 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingfederate \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingfederate:edge
#- ```
#-
#- Follow Docker logs with:
#-
#- ```
#- docker logs -f pingfederate
#- ```
#-
#- If using the command above with the embedded [server profile](https://devops.pingidentity.com/reference/config/), log in with:
#- * https://localhost:9999/pingfederate/app
#-   * Username: Administrator
#-   * Password: 2FederateM0re
