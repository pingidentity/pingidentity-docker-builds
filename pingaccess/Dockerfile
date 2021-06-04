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
#- - `pingidentity/pingdownloader` - Used to download product bits
# Default to Alpine
ARG PRODUCT
ARG SHIM
ARG SHIM_TAG
ARG VERSION
ARG JVM
ARG REGISTRY
ARG DEPS
ARG GIT_TAG
ARG ARCH

FROM ${REGISTRY}/${PRODUCT}:staging-${VERSION}-${GIT_TAG} as product-staging
FROM ${REGISTRY}/pingcommon:${GIT_TAG}-${ARCH} as common
FROM ${REGISTRY}/pingjvm:${JVM}_${SHIM_TAG}-${GIT_TAG}-${ARCH} as jvm

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

#
# the final image
#
FROM ${REGISTRY}/pingbase:${GIT_TAG}-${ARCH}
# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
ARG LICENSE_VERSION

ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
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
    PA_ADMIN_PASSWORD=${INITIAL_ADMIN_PASSWORD} \
    OPERATIONAL_MODE="STANDALONE" \
#-- Change **non-default** password at startup by including this and PING_IDENTITY_PASSWORD
    PA_ADMIN_PASSWORD_INITIAL="2Access" \
#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh" \
#-- Files tailed once container has started
    TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/pingaccess.log \
    PA_ADMIN_PORT=9000 \
# pingaccess comes ootb listening on 3000 but it is more natural for https traffic to be listened for on 443
    PA_ENGINE_PORT=3000
#-- Specify a password for administrator user for interaction with admin API
ENV PING_IDENTITY_PASSWORD=${PA_ADMIN_PASSWORD}

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL image-version="${IMAGE_VERSION}" \
      image-git-rev="${IMAGE_GIT_REV}"


EXPOSE ${PA_ADMIN_PORT} ${PA_ENGINE_PORT} ${HTTPS_PORT}
COPY --from=final-staging ["/","/"]

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
