#- # Ping Identity DevOps Docker Image - `pingauthorizepap`
#-
#- This docker image includes the Ping Identity PingAuthorize Policy Editor product binaries
#- and associated hook scripts to create and run a PingAuthorize Policy Editor instance.
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

# Run build
RUN ["/opt/build.sh"]

#################################################################################

# The final image
FROM ${REGISTRY}/pingbase:${GIT_TAG}-${ARCH}
# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
ARG VERSION
# PingIdentity license version
ARG LICENSE_VERSION

ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
    PING_PRODUCT_VERSION=${VERSION} \
#-- Ping product name
    PING_PRODUCT=PingAuthorize-PAP \
#-- PD License directory. This value is set from the pingbase dockerfile
    LICENSE_DIR="${PD_LICENSE_DIR}" \
#-- Name of license File
    LICENSE_FILE_NAME=PingAuthorize.lic \
#-- Short name used when retrieving license from License Server
    LICENSE_SHORT_NAME=PingAuthorize \
#-- Version used when retrieving license from License Server
    LICENSE_VERSION=${LICENSE_VERSION} \
#-- Minimal Heap size required for PingAuthorize Policy Editor
    MAX_HEAP_SIZE=384m \
#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server" \
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="--nodetach" \
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
    STARTUP_BACKGROUND_OPTS="" \
#-- Location of the keystore file containing the server certificate.
#-- If left undefined, the SECRETS_DIR will be checked for a keystore.
#-- If that keystore does not exist, the server will generate a self-signed certificate.
    KEYSTORE_FILE= \
#-- Location of the pin file for the keystore defined in KEYSTORE_FILE.
#-- If left undefined, the SECRETS_DIR will be checked for a pin file.
#-- This value does not need to be defined when allowing the server to generate a
#-- self-signed certificate.
    KEYSTORE_PIN_FILE= \
#-- Format of the keystore defined in KEYSTORE_FILE. One of "jks" or "pkcs12".
#-- If not defined, the keystore format will be inferred based on the file
#-- extension of the KEYSTORE_FILE, defaulting to "jks".
    KEYSTORE_TYPE= \
#-- Files tailed once container has started
    TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/pingauthorize-pap.log ${SERVER_ROOT_DIR}/logs/setup.log ${SERVER_ROOT_DIR}/logs/start-server.log ${SERVER_ROOT_DIR}/logs/stop-server.log" \

#-- Hostname used for the REST API (deprecated, use `PING_EXTERNAL_BASE_URL` instead)
    REST_API_HOSTNAME="localhost" \

#-- Define shared secret between PAZ and the Policy Editor
    DECISION_POINT_SHARED_SECRET="2FederateM0re" \
#-- When set to `false`, disables default HTTP API caching in the Policy Manager, Trust Framework and Test Suite
    PING_ENABLE_API_HTTP_CACHE=true

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL image-version="${IMAGE_VERSION}" \
      image-git-rev="${IMAGE_GIT_REV}"

EXPOSE ${HTTPS_PORT}

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
#- variables:
#-
#- ```sh
#-   docker run \
#-            --name pingauthorizepap \
#-            --env PING_EXTERNAL_BASE_URL=my-pe-hostname:8443 \
#-            --env PING_OIDC_CONFIGURATION_ENDPOINT=https://my-oidc-provider/.well-known/openid-configuration \
#-            --env PING_CLIENT_ID=b1929abc-e108-4b4f-83d467059fa1 \
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
#- not specified, then the PingAuthorize Policy Editor will be set up in demo mode.
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
#- The cron expression will be evaluated against the container timezone,
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
#-            pingidentity/pingauthorizepap:edge
#- ```
#-
#-
