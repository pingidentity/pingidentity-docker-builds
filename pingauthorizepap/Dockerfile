#- # Ping Identity DevOps Docker Image - `pingauthorizepap`
#-
#- This docker image includes the Ping Identity PingAuthorize Policy Editor product binaries
#- and associated hook scripts to create and run a PingAuthorize Policy Editor instance.
#-
#- ## Related Docker Images
#- - `pingbase-java` (Ping-provided base image) - Parent Image
#-

#################################################################################

# Top level ARGS used in all FROM commands
ARG ARCH
# Keep DEPS: the alpine product-staging stage downloads product bits through
# the deps pull-through registry.
ARG DEPS
# Base image adoption: CI passes BASE_IMAGE (+ JAVA_LINK for JVM
# products). Production CI fail-fasts on unmapped jvm ids before ever
# reaching here.
ARG BASE_IMAGE
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

# Get Ping-wide common scripts from the build context (the old
# pingcommon/pingdatacommon carrier images are retired — plain build inputs now).
COPY ["runtime/common/get-product-bits.sh","/opt/get-product-bits.sh"]

# Get local filesystem product bits if present
COPY ["pingauthorizepap/tmp/", "/tmp/"]

# Download the product bits
RUN /opt/get-product-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip -q /tmp/product.zip -d /tmp/ \
        -x *.bat \
        -x *.dll \
        -x *.exe \
        -x */start-ds \
        -x */stop-ds \
        -x */docs/* \
        -x */uninstall \
        -x */webapps/* \
        -x */_script-util.sh \
    && mv /tmp/PingAuthorize-PAP /opt/server

#################################################################################

FROM ${BASE_IMAGE} AS final-staging

# Ping-provided base images end at USER 9031:0; staging RUN steps run as root.
USER 0:0
# The Ping-provided alpine base ships tini at /sbin/tini (same path the ENTRYPOINT uses).
# Re-declared: top-level ARGs are not inherited into stage RUN scope.
ARG JAVA_LINK
# Preserve the JAVA_HOME=/opt/java contract (pingbase env + PATH); the link
# target lives inside the Ping-provided base image.
RUN if test -n "${JAVA_LINK}"; then ln -s "${JAVA_LINK}" /opt/java; fi

# get the product bits FIRST
COPY --from=product-staging ["/opt/","/opt/"]

# get Ping-wide common scripts
#   this needs to happen after the bits have been laid down
#   so they can be patched
COPY ["runtime/common/","/opt/"]
# get the PingData-family overlay scripts (layered on top of the common set)
COPY ["runtime/pingdata/","/opt/"]

# apply product-specific hooks and patches
COPY ["pingauthorizepap/opt","/opt"]

# add legal information in licenses directory
COPY --from=product-staging ["/opt/server/legal/","/licenses/"]

# Run build
RUN ["/opt/build.sh"]

#################################################################################

# The final image (Ping-provided base image — PDI-2523 final-stage unification; the v1
# pingbase env-carrier stage is retired, so the env vars it used to supply
# to the hook framework are re-declared below).
FROM ${BASE_IMAGE}

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
    PING_PRODUCT=PingAuthorize-PAP \
#-- PD License directory (staged PingData profile pre-setup, where the
#-- PD license is placed by the staging hooks)
    LICENSE_DIR="${PD_LICENSE_DIR}" \
#-- Name of license File
    LICENSE_FILE_NAME=PingAuthorize.lic \
#-- Short name used when retrieving license from License Server
    LICENSE_SHORT_NAME=PingAuthorize \
#-- Version used when retrieving license from License Server
    LICENSE_VERSION=${LICENSE_VERSION} \
#-- Minimal Heap size required for PingAuthorize Policy Editor
    MAX_HEAP_SIZE=384m \
#// PING_USE_CONTAINER_MESSAGES is a Policy Editor (PAP) specific environment
#// variable that tells the product to use container-specific messages in
#// start-server. It is not intended or documented for external use.
    PING_USE_CONTAINER_MESSAGES=true \
#-- The command that the entrypoint executes in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server" \
#-- The command-line options to provide to the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="--nodetach" \
#-- The command-line options to provide to the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
    STARTUP_BACKGROUND_OPTS="" \
#-- Location of the keystore file containing the server certificate.
#-- If left undefined, the SECRETS_DIR will be checked for a keystore.
#-- If that keystore does not exist, the server will generate a self-signed certificate.
    KEYSTORE_FILE= \
#-- Location of the pin file for the keystore defined in KEYSTORE_FILE.
#-- You must specify a KEYSTORE_PIN_FILE when a KEYSTORE_FILE is present.
#-- This value does not need to be defined when allowing the server to generate a
#-- self-signed certificate.
    KEYSTORE_PIN_FILE= \
#-- Format of the keystore defined in KEYSTORE_FILE. One of "jks" or "pkcs12".
#-- If not defined, the keystore format will be inferred based on the file
#-- extension of the KEYSTORE_FILE, defaulting to "jks".
    KEYSTORE_TYPE= \
#-- Files tailed once container has started
    TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/authorize-pe.log ${SERVER_ROOT_DIR}/logs/management-audit.log ${SERVER_ROOT_DIR}/logs/policy-db.log ${SERVER_ROOT_DIR}/logs/setup.log ${SERVER_ROOT_DIR}/logs/start-server.log ${SERVER_ROOT_DIR}/logs/stop-server.log" \

#-- Hostname used for the REST API (deprecated, use `PING_EXTERNAL_BASE_URL` instead)
    REST_API_HOSTNAME="localhost" \

#-- Defines the shared secret between PAZ and the Policy Editor
    DECISION_POINT_SHARED_SECRET="2FederateM0re" \
#-- When set to `false`, disables the default HTTP API caching in the Policy Manager, Trust Framework, and Test Suite
    PING_ENABLE_API_HTTP_CACHE=true \
#-- When set to `true`, the container uses the provided policy database admin credentials
#-- to either create a PostgreSQL policy database or upgrade it if it already exists.
#-- You must also provide the `PING_DB_CONNECTION_STRING`, `PING_DB_ADMIN_USERNAME`, `PING_DB_ADMIN_PASSWORD`
#-- `PING_DB_APP_USERNAME`, and `PING_DB_APP_PASSWORD` variables for this to work.
    PING_POLICY_DB_SYNC= \
#-- The JDBC connection string used to connect to the policy database. Use the format
#-- `jdbc:postgresql://<host>:<port>/<database>`. Only H2 embedded files and PostgreSQL are supported.
    PING_DB_CONNECTION_STRING="jdbc:h2:file:./Symphonic;ALIAS_COLUMN_NAME=TRUE" \
#-- The database administration username to use when creating or upgrading a policy database.
    PING_DB_ADMIN_USERNAME="sa" \
#-- The database administration password to use when creating or upgrading a policy database.
    PING_DB_ADMIN_PASSWORD="Passw0rd" \
#-- The username that the Policy Editor should use when accessing the policy database during server runtime.
    PING_DB_APP_USERNAME="pap_user" \
#-- The password that the Policy Editor should use when accessing the policy database during server runtime.
    PING_DB_APP_PASSWORD="Symphonic2014!"

# WORKDIR parity with the v1 env-carrier (WORKDIR /opt): the Ping-provided base sets /
# (PDI-2523 unification). ENTRYPOINT below is absolute either way, but
# exec/interactive sessions kept the /opt default (PF precedent).
WORKDIR ${BASE}

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL name="${PING_PRODUCT}" \
      version="${IMAGE_VERSION}" \
      release="${IMAGE_GIT_REV}" \
      date="${DATE}" \
      summary="PingAuthorize-PAP provides the PingAuthorize Policy Editor." \
      description="PingAuthorize-PAP includes the Ping Identity PingAuthorize Policy Editor product binaries and associated hook scripts to create and run a PingAuthorize Policy Editor instance."

EXPOSE ${HTTPS_PORT}

# Explicit entrypoint chain (PDI-2523 unification): the v1 pingbase
# env-carrier stage used to supply `ENTRYPOINT ["./bootstrap.sh"]`. Absolute
# paths — the Ping-provided base's WORKDIR is /, not /opt. /sbin/tini (0.19.0) ships in
# the Ping-provided base itself.
ENTRYPOINT ["/sbin/tini", "--", "/opt/bootstrap.sh"]
CMD ["start-server"]

# Legal pointer (was shipped by the v1 pingbase carrier as /licenses/license.txt;
# re-homed to the build context for the Ping-provided base image, which ships no /licenses).
COPY ["legal/license.txt", "/licenses/license.txt"]

COPY --from=final-staging ["/","/"]

#- ## Running a PingAuthorize Policy Editor container
#-
#- A PingAuthorize Policy Editor may be set up in one of two modes:
#-
#- * **Demo mode**: Uses insecure username/password authentication.
#- * **OIDC mode**: Uses an OpenID Connect provider for authentication.
#-
#- To run a PingAuthorize Policy Editor container in demo mode:
#-
#- ```sh
#-   docker run \
#-            --name pingauthorizepap \
#-            --env PING_EXTERNAL_BASE_URL=my-pap-hostname:8443 \
#-            --publish 8443:1443 \
#-            --detach \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingauthorizepap:edge
#- ```
#-
#- Log in with:
#-
#- - https://my-pap-hostname:8443/
#-     - Username: admin
#-     - Password: password123
#-
#- To run a PingAuthorize Policy Editor container in OpenID Connect mode, specify
#- the `PING_OIDC_CONFIGURATION_ENDPOINT` and `PING_CLIENT_ID` environment
#- variables. To provide scopes other than the default (`oidc email profile`),
#- specify the `PING_SCOPE` environment variable:
#-
#- ```sh
#-   docker run \
#-            --name pingauthorizepap \
#-            --env PING_EXTERNAL_BASE_URL=my-pe-hostname:8443 \
#-            --env PING_OIDC_CONFIGURATION_ENDPOINT=https://my-oidc-provider/.well-known/openid-configuration \
#-            --env PING_CLIENT_ID=b1929abc-e108-4b4f-83d467059fa1 \
#-            --env PING_SCOPE="oidc email profile phone" \
#-            --publish 8443:1443 \
#-            --detach \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingauthorizepap:edge
#- ```
#-
#- Note: If both `PING_OIDC_CONFIGURATION_ENDPOINT` and `PING_CLIENT_ID` are
#- not specified, then Docker sets up the PingAuthorize Policy Editor container in demo mode.
#-
#- Log in with:
#-
#- - https://my-pap-hostname:8443/
#-     - Provide credentials as prompted by the OIDC provider
#-
#- Follow Docker logs with:
#-
#- ```sh
#- docker logs -f pingauthorizepap
#- ```
#-
#-
#- ## Specifying the external hostname and port
#-
#- The Policy Editor consists of a client-side application that runs in the user's web
#- browser and a backend REST API service that runs within the container. So
#- that the client-side application can successfully make API calls to the
#- backend, the Policy Editor must be configured with an externally accessible
#- hostname:port. If the Policy Editor is configured in OIDC mode, then the external
#- hostname:port pair is also needed so that the Policy Editor can correctly generate its
#- OIDC redirect URI.
#-
#- Use the `PING_EXTERNAL_BASE_URL` environment variable to specify the Policy Editor's
#- external hostname and port using the form `hostname[:port]`, where `hostname`
#- is the hostname of the Docker host and `port` is the Policy Editor container's published
#- port. If the published port is 443, then it should be omitted.
#-
#- For example:
#-
#- ```sh
#-   docker run \
#-            --name pingauthorizepap \
#-            --env PING_EXTERNAL_BASE_URL=my-pap-hostname:8443 \
#-            --publish 8443:1443 \
#-            --detach \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingauthorizepap:edge
#- ```
#-
#-
#- ## Changing the default periodic database backup schedule and location
#-
#- The PAP performs periodic backups of the policy database. The results
#- are placed in the `policy-backup` directory underneath the instance root.
#-
#- Use the `PING_BACKUP_SCHEDULE` environment variable to specify the PAP's
#- periodic database backup schedule in the form of a cron expression.
#- The cron expression evaluates against the container timezone,
#- UTC. Use the `PING_H2_BACKUP_DIR` environment variable to change the
#- backup output directory.
#-
#- For example, to perform backups daily at UTC noon and place backups in
#- `/opt/out/backup`:
#-
#- ```sh
#-   docker run \
#-            --name pingauthorizepap \
#-            --env PING_EXTERNAL_BASE_URL=my-pap-hostname:8443 \
#-            --env PING_BACKUP_SCHEDULE="0 0 12 * * ?" \
#-            --env PING_H2_BACKUP_DIR=/opt/out/backup \
#-            --publish 8443:1443 \
#-            --detach \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingauthorizepap:edge
#- ```
#-
#-
#-
#- ## Creating and upgrading a PostgreSQL policy database
#-
#- Although the Policy Editor uses an embedded H2 file for its policy
#- database implementation by default, it also has the capability to use
#- a PostgreSQL database. However, this database must first be initialized
#- with database objects.
#-
#- Set the `PING_POLICY_DB_SYNC` environment variable to `true`, provide
#- the PostgreSQL JDBC connection string in `PING_DB_CONNECTION_STRING`,
#- the database administration credentials through `PING_DB_ADMIN_USERNAME`
#- and `PING_DB_ADMIN_PASSWORD`, and the server runtime credentials through
#- `PING_DB_APP_USERNAME` and `PING_DB_APP_PASSWORD` to indicate that
#- pingauthorizepap should create the necessary policy database objects.
#-
#- Similarly, use the same environment variables with the same values
#- when a new version of the application is released. pingauthorizepap
#- will use the database administration user to perform any necessary upgrades to the
#- database objects.
#-
#- In both scenarios, the database administration user and the server runtime user
#- must exist and be able to sign into the PostgreSQL server. In the create
#- scenario, the database administration user must be able to create databases.
#- In the upgrade scenario, the database administration user must own the database
#- objects. Therefore, it is advisable to continually provide the same
#- administration credentials during creation and upgrades to prevent permissions issues.
#-
#- For example, assume that a system administrator has created a
#- PostgreSQL username `pap_admin` that can sign into a PostgreSQL server hosted at
#- example.com and listening on port 5432. They have also created the runtime user
#- `pap_user`.
#-
#- To create the database objects under the database named `my_pap_db` and start the Policy Editor,
#- use the following command:
#-
#- ```sh
#-   docker run \
#-            --name pingauthorizepap \
#-            --env PING_EXTERNAL_BASE_URL=my-pap-hostname:8443 \
#-            --env PING_POLICY_DB_SYNC=true \
#-            --env PING_DB_CONNECTION_STRING=jdbc:postgresql://example.com:5432/my_pap_db \
#-            --env PING_DB_ADMIN_USERNAME=pap_admin \
#-            --env PING_DB_ADMIN_PASSWORD=2FederateM0re \
#-            --env PING_DB_APP_USERNAME=pap_user \
#-            --env PING_DB_APP_PASSWORD=2FederateM0re \
#-            --publish 8443:1443 \
#-            --detach \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingauthorizepap:edge
#- ```
#-
#- Use the same command when a new pingauthorizepap release requires an upgrade to the policy
#- database schema.
#-
#- Note that `PING_DB_ADMIN_PASSWORD` and `PING_DB_APP_PASSWORD` are only provided on the
#- command line for illustrative purposes and can instead be provided through a Vault or
#- through a `/run/secrets` `.env` file.
#-
