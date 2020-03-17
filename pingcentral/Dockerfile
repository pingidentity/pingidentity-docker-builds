#- # Ping Identity DevOps Docker Image - `pingcentral`
#- 
#- This docker image includes the Ping Identity PingCentral product binaries
#- and associated hook scripts to create and run PingCentral in a container.
#-
#- ## Related Docker Images
#- - pingidentity/pingbase - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://pingidentity-devops.gitbook.io/devops/docker-images/pingbase)**
#- - pingidentity/pingcommon - Common Ping files (i.e. hook scripts)
#- - pingidentity/pingdownloader - Used to download product bits
#-
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
ENV PING_CENTRAL_SERVER_PORT=9022
ENV PING_PRODUCT="PingCentral"
ENV LICENSE_DIR="${SERVER_ROOT_DIR}/conf"
ENV LICENSE_FILE_NAME="pingcentral.lic"
ENV LICENSE_SHORT_NAME="PC"
ENV LICENSE_VERSION=${LICENSE_VERSION}
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh"
ENV TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/application.log
ENV PING_CENTRAL_LOG_LEVEL="INFO"
ENV PING_CENTRAL_BLIND_TRUST=false
ENV PING_CENTRAL_VERIFY_HOSTNAME=true

EXPOSE 9022
COPY --from=final-staging ["/","/"]

#- ## Running a PingCentral container
#- To run a PingCentral container with your devops configuration file:
#- ```shell docker run -Pt \
#-            --name pingcentral \
#-            --env-file ~/.pingidentity/devops \
#-            pingidentity/pingcentral:edge
#- ```
#- or with long options in the background:
#- ```shell
#-   docker run \
#-            --name pingcentral \
#-            --publish 9022:9022 \
#-            --detach \
#-            --env-file ~/.pingidentity/devops \
#-            pingidentity/pingcentral:edge
#- ```
#- 
#- or if you want to specify everything yourself:
#- ```shell
#-   docker run \
#-            --name pingcentral \
#-            --publish 9022:9022 \
#-            --detach \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER=<yourdevopsuser@example.com> \
#-            --env PING_IDENTITY_DEVOPS_KEY=<yourdevopskeyhere> \
#-            pingidentity/pingcentral:edge
#- ```
#- 
#- Follow Docker logs with:
#- 
#- ``` shell
#- docker logs -f pingcentral
#- ```
#- 
#- If using the command above with the embedded [server profile](../server-profiles/README.md), log in with: 
#- * https://localhost:9022/
#-   * Username: Administrator
#-   * Password: 2Federate