#- # Ping Identity DevOps Docker Image - `pingdirectory`
#-
#- This docker image includes the Ping Identity PingDirectory product binaries
#- and associated hook scripts to create and run a PingDirectory instance or
#- instances.
#-
#- ## Related Docker Images
#- - `pingidentity/pingbase` - Parent Image
#- > This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)
#- - `pingidentity/pingdatacommon` - Common Ping files (i.e. hook scripts)
#-

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

FROM ${REGISTRY}/pingdatacommon:${GIT_TAG}-${ARCH} as common
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
# TODO Remove "unzip" and "find" logic once FEDRAMP images have been updated to PD version 9.0 or newer using docker zip files
RUN /opt/get-product-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip -q /tmp/product.zip -d /tmp/ \
        -x *.bat \
        -x *.dll \
        -x *.exe \
        -x */start-ds \
        -x */stop-ds \
        -x */uninstall \
        -x */webapps/* \
        -x */resource/*.zip \
        -x */_script-util.sh \
        -x */lib/wrapper.jar \
    && find /tmp/PingDirectory/docs -type f \
        ! -iname "unboundid.css" \
        ! -path "/tmp/PingDirectory/docs/images/*" \
        ! -path "/tmp/PingDirectory/docs/rest-api-specs/*" \
        -delete \
    && mv /tmp/PingDirectory /opt/server

#################################################################################

FROM ${DEPS}${SHIM} as final-staging
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

# The final image
FROM ${REGISTRY}/pingbase:${GIT_TAG}-${ARCH}
# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
ARG DATE
ARG VERSION
# PingIdentity license version
ARG LICENSE_VERSION

ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
    DATE=${DATE} \
    PING_PRODUCT_VERSION=${VERSION} \
#-- Ping product name
    PING_PRODUCT=PingDirectory \
#-- PD License directory. This value is set from the pingbase docker file
    LICENSE_DIR="${PD_LICENSE_DIR}" \
#-- Name of license File
    LICENSE_FILE_NAME="PingDirectory.lic" \
#-- Short name used when retrieving license from License Server
    LICENSE_SHORT_NAME=PD \
#-- Version used when retrieving license from License Server
    LICENSE_VERSION=${LICENSE_VERSION} \

#-- Default PingDirectory Replication Port
    REPLICATION_PORT=8989 \
#-- Replication administrative user
    ADMIN_USER_NAME=admin \

#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server" \

#-- Public hostname of the DA app
    PD_DELEGATOR_PUBLIC_HOSTNAME=localhost \

#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="--nodetach" \

#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
    STARTUP_BACKGROUND_OPTS="" \

#-- Location of file with the root user password (i.e. cn=directory manager).
#-- Defaults to /SECRETS_DIR/root-user-password
    ROOT_USER_PASSWORD_FILE= \

#-- Location of file with the admin password, used as the password replication admin
#-- Defaults to /SECRETS_DIR/admin-user-password
    ADMIN_USER_PASSWORD_FILE= \

#-- Location of file with the passphrase for setting up encryption
#-- Defaults to /SECRETS_DIR/encryption-password
    ENCRYPTION_PASSWORD_FILE= \

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
    TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/access ${SERVER_ROOT_DIR}/logs/errors ${SERVER_ROOT_DIR}/logs/failed-ops ${SERVER_ROOT_DIR}/logs/config-audit.log ${SERVER_ROOT_DIR}/logs/debug-trace ${SERVER_ROOT_DIR}/logs/debug-aci ${SERVER_ROOT_DIR}/logs/tools/*.log* ${SERVER_BITS_DIR}/logs/tools/*.log* " \
#-- Number of users to auto-populate using make-ldif templates
    MAKELDIF_USERS=0 \

#-- The default retry timeout in seconds for dsreplication and
#-- remove-defunct-server
    RETRY_TIMEOUT_SECONDS=180 \

#-- Directory for the profile used by the PingData manage-profile tool
    PD_PROFILE="${STAGING_DIR}/pd.profile" \

#-- Turns on FIPS mode (currently with the Bouncy Castle FIPS provider)
#-- set to exactly "true" lowercase to turn on
#-- set to anything else to turn off
    FIPS_MODE_ON=false \

#-- BCFIPS is the only provider currently supported -- do not edit
    FIPS_PROVIDER="BCFIPS" \

#-- Force a rebuild (replace-profile) of a PingDirectoy on restart.
#-- Used to ensure that the server configuration exactly matches the server profile.
#-- This variable will slow down startup times and should only be used
#-- when necessary.
    PD_REBUILD_ON_RESTART=false \

#-- Setting this variable to true speeds up server startup time by
#-- skipping an unnecessary JVM check.
    UNBOUNDID_SKIP_START_PRECHECK_NODETACH=true \

#-- Base DNs to include when enabling replication, in addition to the
#-- always-included USER_BASE_DN. Multiple base DNs can be specified here,
#-- separated by a `;` character
    REPLICATION_BASE_DNS= \

#-- Base DNs to set as --restricted when enabling replication. Multiple
#-- base DNs can be specified here, separated by a `;` character.
#-- See the product documentation for more information on how to configure entry balancing.
    RESTRICTED_BASE_DNS= \

#-- Whether this container is running as a Pod in a Kubernetes StatefulSet, and
#-- that StatefulSet is using the Parallel podManagementPolicy. This property allows
#-- for starting up Pods in parallel to speed up the initial startup of PingDirectory
#-- topologies. This variable must be set to true when using the Parallel podManagementPolicy.
#-- Note: when using parallel startup, ensure the RETRY_TIMEOUT_SECONDS variable is
#-- large enough. The pods will be enabling replication simultaneously, so some pods
#-- will have to retry while waiting for others to complete. If the timeout is too low,
#-- a Pod may end up restarting unnecessarily.
    PARALLEL_POD_MANAGEMENT_POLICY=false \

#-- Set to true to skip the waiting for DNS step that is normally done just before
#-- attempting to join the topology.
    SKIP_WAIT_FOR_DNS=false \

#-- There is an additional certificate-based variable used to identity the certificate alias 
#-- used within the `KEYSTORE_FILE`. That variable is called `CERTIFICATE_NICKNAME`,
#-- which identifies the certificate to use by the server in the `KEYSTORE_FILE`. 
#-- If a value is not provided, the container will look at the list certs found in the 
#-- `KEYSTORE_FILE` and if one - and only one - certificate is found of type `PrivateKeyEntry`,
#-- that alias will be used.
    CERTIFICATE_NICKNAME= \

#-- Set to true to force PingDirectory to export and re-import its backend data on restart.
#-- Note that this process can take a long time for large backends.
    PD_FORCE_DATA_REIMPORT=false \

#-- The load-balancing algorithm names to set for this server instance.
#-- This variable is only needed when enabling automatic server discovery with PingDirectoryProxy.
#-- Multiple algorithms can be specified here, separated by a `;` character
    LOAD_BALANCING_ALGORITHM_NAMES= \

#-- Set to true to fail the container if it is found that replication is not enabled
#-- for the USER_BASE_DN during startup. If replication is not enabled for the DN but this variable
#-- is not set to true, then a warning will be printed, but the container will not fail.
    FAIL_ON_DISABLED_BASE_DN=false \

#-- Set to true to fail the container if it is found that a previous call to remove-defunct-server
#-- in the hook scripts failed. If there was a failure but this variable
#-- is not set to true, then a warning will be printed, but the container will not fail.
#-- Failure of remove-defunct-server is marked by a file at ${SERVER_ROOT_DIR}/logs/remove-defunct-server-marker.
#-- Logs for the tool can be found at ${SERVER_ROOT_DIR}/logs/tools/remove-defunct-server.log
    FAIL_ON_UNSUCCESSFUL_REMOVE_DEFUNCT=false \

#-- Sets the number of columns in PingDirectory command-line tool output
    COLUMNS=120

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL name="${PING_PRODUCT}" \
      version="${IMAGE_VERSION}" \
      release="${IMAGE_GIT_REV}" \
      date="${DATE}" \
      summary="The PingDirectory suite of products includes the PingDirectory server, the PingDirectoryProxy server, the Delegated Admin application, the PingDataSync server, and the PingDataMetrics server." \
      description="The PingDirectory server centralizes consumer and user identity management information, subscriber data management, application configurations, and user credentials into a network, enterprise, or virtualized database environment"

EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT}

COPY --from=final-staging ["/","/"]

#- ## Running a PingDirectory container
#-
#- The easiest way to test test a simple standalone image of PingDirectory is to cut/paste the following command into a terminal on a machine with docker.
#-
#- ```
#-   docker run \
#-            --name pingdirectory \
#-            --publish 1389:1389 \
#-            --publish 8443:1443 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingdirectory \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingdirectory:edge
#- ```
#-
#- You can view the Docker logs with the command:
#-
#- ```
#-   docker logs -f pingdirectory
#- ```
#-
#- You should see the ouptut from a PingDirectory install and configuration, ending with a message the the PingDirectory has started.  After it starts, you will see some typical access logs.  Simply ``Ctrl-C`` after to stop tailing the logs.
#-
#- ## Running a sample 100/sec search rate test
#- With the PingDirectory running from the previous section, you can run a ``searchrate`` job that will send load to the directory at a rate if 100/sec using the following command.
#-
#- ```
#- docker exec -it pingdirectory \
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
#-   docker container stop pingdirectory
#- ```
#-
#- To remove the container:
#-
#- ```
#-   docker container rm -f pingdirectory
#- ```
