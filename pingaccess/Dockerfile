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
ARG JDK

FROM pingidentity/${PRODUCT}:staging-${VERSION} as product-staging
FROM pingidentity/pingcommon as common
FROM pingidentity/pingjvm:${JDK}_${SHIM_TAG} as jvm

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
FROM pingidentity/pingbase:${SHIM_TAG}
# pingaccess comes ootb listening on 3000 but it is more natural for https traffic to be listened for on 443
EXPOSE 9000 3000 ${HTTPS_PORT}
ENV PING_PRODUCT="PingAccess"
ENV LICENSE_DIR="${SERVER_ROOT_DIR}/conf"
ENV LICENSE_FILE_NAME=pingaccess.lic
ENV LICENSE_SHORT_NAME=PA
ENV LICENSE_VERSION=5.2
ENV INITIAL_ADMIN_PASSWORD="${INITIAL_ADMIN_PASSWORD:-2FederateM0re}"
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh"
ENV TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/pingaccess.log
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