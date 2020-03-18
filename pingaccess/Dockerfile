#- # Ping Identity DevOps Docker Image - `pingaccess`
#- 
#- This docker image includes the Ping Identity PingAccess product binaries
#- and associated hook scripts to create and run both PingAccess Admin and
#- Engine nodes. 
#-
#- ## Related Docker Images
#- - `pingidentity/pingbase` - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://pingidentity-devops.gitbook.io/devops/docker-images/pingbase)**
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
ARG GIT_TAG

FROM ${REGISTRY}/${PRODUCT}:staging-${VERSION}-${GIT_TAG} as product-staging
FROM ${REGISTRY}/pingcommon:${GIT_TAG} as common
FROM ${REGISTRY}/pingjvm:${JVM}_${SHIM_TAG}-${GIT_TAG} as jvm

FROM ${SHIM} as final-staging
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
ARG LICENSE_VERSION
# pingaccess comes ootb listening on 3000 but it is more natural for https traffic to be listened for on 443
ENV PING_PRODUCT="PingAccess"
ENV LICENSE_DIR="${SERVER_ROOT_DIR}/conf"
ENV LICENSE_FILE_NAME=pingaccess.lic
ENV LICENSE_SHORT_NAME=PA
ENV LICENSE_VERSION=${LICENSE_VERSION}
#-- Specify a password for administrator user for interaction with admin API
ENV PA_ADMIN_PASSWORD="${INITIAL_ADMIN_PASSWORD:-2FederateM0re}"
#-- Change **non-default** password at startup by including this and PA_ADMIN_PASSWORD
ENV PA_ADMIN_PASSWORD_INITIAL="2Access"
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh"
ENV TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/pingaccess.log

EXPOSE 9000 3000 ${HTTPS_PORT}
COPY --from=final-staging ["/","/"]

#- ## Running a PingDirectory container
#- To run a PingAccess container: 
#- 
#- ```shell
#-   docker run \
#-            --name pingaccess \
#-            --publish 9000:9000 \
#-            --publish 443:443 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingaccess \
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
#- If using the command above with the embedded [server profile](../server-profiles/README.md), log in with: 
#- * https://localhost:9000
#-   * Username: Administrator
#-   * Password: 2FederateM0re