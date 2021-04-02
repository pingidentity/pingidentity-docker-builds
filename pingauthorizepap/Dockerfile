#- # Ping Identity DevOps Docker Image - `pingauthorizepap`
#-
#- This docker image includes the Ping Identity PingAuthorize Policy Editor product binaries
#- and associated hook scripts to create and run a PingAuthorize Policy Editor instance.
#-
#- ## Related Docker Images
#- - `pingidentity/pingbase` - Parent Image
#- > This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)
#- - `pingidentity/pingdatacommon` - Common Ping files (i.e. hook scripts)
#- - `pingidentity/pingdownloader` - Used to download product bits
#-
ARG PRODUCT
ARG SHIM
ARG SHIM_TAG
ARG VERSION
ARG JVM
ARG REGISTRY
ARG DEPS
ARG GIT_TAG

FROM ${REGISTRY}/${PRODUCT}:staging-${VERSION}-${GIT_TAG} as product-staging
FROM ${REGISTRY}/pingdatacommon:${GIT_TAG} as common
FROM ${REGISTRY}/pingjvm:${JVM}_${SHIM_TAG}-${GIT_TAG} as jvm

FROM ${DEPS}${SHIM} as final-staging
ENV SHIM=${SHIM}

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


FROM ${REGISTRY}/pingbase:${GIT_TAG}
#-- Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ENV IMAGE_VERSION=${IMAGE_VERSION}
ARG IMAGE_GIT_REV=""
ENV IMAGE_GIT_REV=${IMAGE_GIT_REV}

LABEL image-version="${IMAGE_VERSION}" \
      image-git-rev="${IMAGE_GIT_REV}"

#-- PingIdentity license version
ARG LICENSE_VERSION
#-- Ping product name
ENV PING_PRODUCT=PingAuthorize-PAP
#-- Name of License File
ENV LICENSE_FILE_NAME=PingAuthorize.lic
#-- Shortname used when retrieving license from License Server
ENV LICENSE_SHORT_NAME=PingAuthorize
#-- Version used when retrieving license from License Server
ENV LICENSE_VERSION=${LICENSE_VERSION}

#-- Minimal Heap size required for PingAuthorize Policy Editor
ENV MAX_HEAP_SIZE=384m

ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server"

#-- Prevent the server from starting in the background
ENV STARTUP_FOREGROUND_OPTS="--nodetach"
ENV STARTUP_BACKGROUND_OPTS=""

#-- Files tailed once container has started
ENV TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/pingauthorize-pap.log \
  ${SERVER_ROOT_DIR}/logs/setup.log \
  ${SERVER_ROOT_DIR}/logs/start-server.log \
  ${SERVER_ROOT_DIR}/logs/stop-server.log"

#-- Hostname used for the REST API (deprecated, use `PING_EXTERNAL_BASE_URL` instead)
ENV REST_API_HOSTNAME="localhost"

#-- Define shared secret between PAZ and the Policy Editor
ENV DECISION_POINT_SHARED_SECRET="2FederateM0re"

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
#- ```
#-   docker run \
#-            --name pingauthorizepap \
#-            --env PING_EXTERNAL_BASE_URL=my-pe-hostname:8443 \
#-            --publish 8443:443 \
#-            --detach \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingauthorizepap:edge
#- ```
#-
#- Log in with:
#- * https://my-pe-hostname:8443/
#-   * Username: admin
#-   * Password: password123
#-
#- To run a PingAuthorize Policy Editor container in OpenID Connect mode, specify
#- the `PING_OIDC_CONFIGURATION_ENDPOINT` and `PING_CLIENT_ID` environment
#- variables:
#-
#- ```
#-   docker run \
#-            --name pingauthorizepap \
#-            --env PING_EXTERNAL_BASE_URL=my-pe-hostname:8443 \
#-            --env PING_OIDC_CONFIGURATION_ENDPOINT=https://my-oidc-provider/.well-known/openid-configuration \
#-            --env PING_CLIENT_ID=b1929abc-e108-4b4f-83d467059fa1 \
#-            --publish 8443:443 \
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
#- * https://my-pe-hostname:8443/
#-   * Provide credentials as prompted by the OIDC provider
#-
#- Follow Docker logs with:
#-
#- ```
#- docker logs -f pingauthorizepap
#- ```
#-
#-
#- ## Specifying the external hostname and port
#-
#- The Policy Editor consists of a client-side application that runs in the user's web
#- browser and a backend REST API service that runs within the container. So
#- that the client-side application can successfully make API calls to the
#- backend, the PE must be configured with an externally accessible
#- hostname:port. If the PE is configured in OIDC mode, then the external
#- hostname:port pair is also needed so that the PE can correctly generate its
#- OIDC redirect URI.
#-
#- Use the `PING_EXTERNAL_BASE_URL` environment variable to specify the PE's
#- external hostname and port using the form `hostname[:port]`, where `hostname`
#- is the hostname of the Docker host and `port` is the PE container's published
#- port. If the published port is 443, then it should be omitted.
#-
#- For example:
#-
#- ```
#-   docker run \
#-            --name pingauthorizepap \
#-            --env PING_EXTERNAL_BASE_URL=my-pe-hostname:8443 \
#-            --publish 8443:443 \
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
#- ```
#-   docker run \
#-            --name pingauthorizepap \
#-            --env PING_EXTERNAL_BASE_URL=my-pe-hostname:8443 \
#-            --env PING_BACKUP_SCHEDULE="0 0 12 * * ?" \
#-            --env PING_H2_BACKUP_DIR=/opt/out/backup \
#-            --publish 8443:443 \
#-            --detach \
#-            pingidentity/pingauthorizepap:edge
#- ```
#-
#-