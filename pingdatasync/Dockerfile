#- # Ping Identity DevOps Docker Image - `pingdatasync`
#-
#- This docker image includes the Ping Identity PingDataSync product binaries
#- and associated hook scripts to create and run a PingDataSync instance.
#-
#- ## Related Docker Images
#- - `pingidentity/pingbase` - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)**
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

#
# The final image
#
FROM ${REGISTRY}/pingbase:${GIT_TAG}
#-- PingIdentity license version
ARG LICENSE_VERSION

ENV TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/sync"
ENV LICENSE_FILE_NAME="PingDirectory.lic"
ENV LICENSE_SHORT_NAME=PD
ENV LICENSE_VERSION=${LICENSE_VERSION}
ENV PING_PRODUCT=PingDataSync
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server"
ENV STARTUP_FOREGROUND_OPTS="--nodetach"

#-- The default retry timeout in seconds for manage-topology and
#-- remove-defunct-server
ENV RETRY_TIMEOUT_SECONDS=180

#-- Failover administrative user
ENV ADMIN_USER_NAME=admin

#-- Location of file with the root user password (i.e. cn=directory manager).
#-- Defaults to the /SECRETS_DIR/root-user-password
ENV ROOT_USER_PASSWORD_FILE=
ENV ADMIN_USER_PASSWORD_FILE=

ENV PD_PROFILE="${STAGING_DIR}/pd.profile"

EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT}

COPY --from=final-staging ["/","/"]

#- ## Running a PingDataSync container
#- ```
#-   docker run \
#-            --name pingdatasync \
#-            --publish 1389:389 \
#-            --publish 8443:443 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=simple-sync/pingdatasync \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingdatasync:edge
#- ```
