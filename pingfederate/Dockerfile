#- # Ping Identity DevOps Docker Image - `pingfederate`
#- 
#- This docker image includes the Ping Identity PingFederate product binaries
#- and associated hook scripts to create and run both PingFederate Admin and
#- Engine nodes. 
#-
#- ## Related Docker Images
#- - pingidentity/pingbase - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://pingidentity-devops.gitbook.io/devops/docker-images/pingbase)**
#- - pingidentity/pingcommon - Common Ping files (i.e. hook scripts)
#- - pingidentity/pingdownloader - Used to download product bits
#-

#
# Staging product to a seperate image saves us the download + staging 
# for each shim a product version is built for
#
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
# The final image 
#
FROM ${REGISTRY}/pingbase:${GIT_TAG}
ARG LICENSE_VERSION
ENV PING_PRODUCT="PingFederate"
ENV LICENSE_DIR="${SERVER_ROOT_DIR}/server/default/conf"
ENV LICENSE_FILE_NAME="pingfederate.lic"
ENV LICENSE_SHORT_NAME="PF"
ENV LICENSE_VERSION=${LICENSE_VERSION}
ENV OPERATIONAL_MODE="STANDALONE"
ENV CLUSTER_BIND_ADDRESS="NON_LOOPBACK"
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh"
ENV TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/server.log
ENV PF_ENGINE_DEBUG=false
ENV PF_ADMIN_DEBUG=false
ENV PF_DEBUG_PORT=9030
ENV PF_ENGINE_PORT=9031
ENV PF_ADMIN_PORT=9999

EXPOSE 9031 9999

# get the staged bits 
COPY --from=final-staging ["/","/"]

#- ## Running a PingFederate container
#- To run a PingFederate container:
#- 
#- ```shell
#-   docker run \
#-            --name pingfederate \
#-            --publish 9999:9999 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingfederate \
#-            pingidentity/pingfederate:edge
#- ```
#- 
#- Follow Docker logs with:
#- 
#- ```
#- docker logs -f pingfederate
#- ```
#- 
#- If using the command above with the embedded [server profile](../server-profiles/README.md), log in with: 
#- * https://localhost:9999/pingfederate/app
#-   * Username: Administrator
#-   * Password: 2FederateM0re
