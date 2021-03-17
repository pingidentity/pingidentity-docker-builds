#- # Ping Identity DevOps Docker Image - `pingaccess`
#-
#- This docker image includes the Ping Identity PingAccess product binaries
#- and associated hook scripts to create and run both PingAccess Admin and
#- Engine nodes.
#-
#- ## Related Docker Images
#- - `pingidentity/pingbase` - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)**
#- - `pingidentity/pingcommon` - Common Ping files (i.e. hook scripts)
#- - `pingidentity/pingdownloader` - Used to download product bits
#-
# Default to Alpine
ARG PRODUCT
ARG SHIM
ARG SHIM_TAG
ARG VERSION
ARG JVM
ARG REGISTRY
ARG DEPS
ARG GIT_TAG

FROM ${REGISTRY}/${PRODUCT}:staging-${VERSION}-${GIT_TAG} as product-staging
FROM ${REGISTRY}/pingcommon:${GIT_TAG} as common
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
# the final image
#
FROM ${REGISTRY}/pingbase:${GIT_TAG}
#-- Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ENV IMAGE_VERSION=${IMAGE_VERSION}
ARG IMAGE_GIT_REV=""
ENV IMAGE_GIT_REV=${IMAGE_GIT_REV}

LABEL image-version="${IMAGE_VERSION}" \
      image-git-rev="${IMAGE_GIT_REV}"

ARG LICENSE_VERSION
# pingaccess comes ootb listening on 3000 but it is more natural for https traffic to be listened for on 443
ENV PING_PRODUCT="PingAccess"
ENV LICENSE_DIR="${SERVER_ROOT_DIR}/conf"
ENV LICENSE_FILE_NAME=pingaccess.lic
ENV LICENSE_SHORT_NAME=PA
ENV LICENSE_VERSION=${LICENSE_VERSION}
ENV PA_ADMIN_PASSWORD=${INITIAL_ADMIN_PASSWORD}
#-- Specify a password for administrator user for interaction with admin API
ENV PING_IDENTITY_PASSWORD=${PA_ADMIN_PASSWORD}
ENV OPERATIONAL_MODE="STANDALONE"
#-- Change **non-default** password at startup by including this and PING_IDENTITY_PASSWORD
ENV PA_ADMIN_PASSWORD_INITIAL="2Access"
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh"
ENV TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/pingaccess.log
ENV PA_ADMIN_PORT=9000
ENV PA_ENGINE_PORT=3000

EXPOSE ${PA_ADMIN_PORT} ${PA_ENGINE_PORT} ${HTTPS_PORT}
COPY --from=final-staging ["/","/"]

#- ## Running a PingAccess container
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
#-
#- Follow Docker logs with:
#-
#- ```
#- docker logs -f pingaccess
#- ```
#-
#- If using the command above with the embedded [server profile](https://devops.pingidentity.com/reference/config/), log in with:
#- * https://localhost:9000
#-   * Username: Administrator
#-   * Password: 2FederateM0re
