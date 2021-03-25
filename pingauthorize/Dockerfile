#- # Ping Identity DevOps Docker Image - `pingauthorize`
#-
#- This docker image includes the Ping Identity PingAuthorize product binaries
#- and associated hook scripts to create and run a PingAuthorize instance or
#- instances.
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
ENV PING_PRODUCT=PingAuthorize
#-- Name of License File
ENV LICENSE_FILE_NAME=PingAuthorize.lic
#-- Shortname used when retrieving license from License Server
ENV LICENSE_SHORT_NAME=PingAuthorize
#-- Version used when retrieving license from License Server
ENV LICENSE_VERSION=${LICENSE_VERSION}

#-- Minimal Heap size required for PingAuthorize
ENV MAX_HEAP_SIZE=1g

ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server"

#-- Prevent the server from running as a background process
ENV STARTUP_FOREGROUND_OPTS="--nodetach"
ENV STARTUP_BACKGROUND_OPTS=""

#-- Location of file with the root user password (i.e. cn=directory manager).
#-- Defaults to the /SECRETS_DIR/root-user-password
ENV ROOT_USER_PASSWORD_FILE=

#-- Location of file with the passphrase for setting up encryption
#-- Defaults to the /SECRETS_DIR/encryption-password
ENV ENCRYPTION_PASSWORD_FILE=

#-- Files tailed once container has started
ENV TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/access"

ENV PD_PROFILE="${STAGING_DIR}/pd.profile"

EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT} 5005

COPY --from=final-staging ["/","/"]


#- ## Running a PingAuthorize container
#-
#- The easiest way to test a simple standalone image of PingAuthorize is to cut/paste the following command into a terminal on a machine with docker.
#-
#- ```
#-   docker run \
#-            --name pingauthorize \
#-            --publish 1389:389 \
#-            --publish 8443:443 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingauthorize \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-           pingidentity/pingauthorize:edge
#- ```
#-
#- You can view the Docker logs with the command:
#-
#- ```
#-   docker logs -f pingauthorize
#- ```
#-
#- You should see the ouptut from a PingAuthorize install and configuration, ending with a message the the PingAuthorize has
#- started.  After it starts, you will see some typical access logs.  Simply ``Ctrl-C`` afer to stop tailing the logs.
#-
#-
#- ## Stopping/Removing the container
#- To stop the container:
#-
#- ```
#-   docker container stop pingauthorize
#- ```
#-
#- To remove the container:
#-
#- ```
#-   docker container rm -f pingauthorize
#- ```
