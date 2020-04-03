#- # Ping Identity DevOps Docker Image - `pingdatagovernancepap`
#- 
#- This docker image includes the Ping Identity PingDataGovernance PAP product binaries
#- and associated hook scripts to create and run a PingDataGovernance PAP instance.
#-
#- ## Related Docker Images
#- - `tomcat:8-jre8-alpine` - Tomcat engine to serve PingDataConsole .war file
#-
ARG PRODUCT
ARG SHIM
ARG SHIM_TAG
ARG VERSION
ARG JVM
ARG REGISTRY
ARG GIT_TAG

FROM ${REGISTRY}/${PRODUCT}:staging-${VERSION}-${GIT_TAG} as product-staging
FROM ${REGISTRY}/pingdatacommon:${GIT_TAG} as common
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


FROM ${REGISTRY}/pingbase:${GIT_TAG}
#-- PingIdentity license version
ARG LICENSE_VERSION
#-- Ping product name
ENV PING_PRODUCT=PingDataGovernance-PAP
#-- Name of License File
ENV LICENSE_FILE_NAME=PingDataGovernance.lic
#-- Shortname used when retrieving license from License Server
ENV LICENSE_SHORT_NAME=PG
#-- Version used when retrieving license from License Server
ENV LICENSE_VERSION=${LICENSE_VERSION}

#-- Minimal Heap size required for Ping DataGovernance
ENV MAX_HEAP_SIZE=384m

ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server"

#-- Adding lockdown mode so non administrive connections be made until server
#-- has been started with replication enabled
ENV STARTUP_FOREGROUND_OPTS="--nodetach"

#-- Adding lockdown mode so non administrive connections be made until server
#-- has been started with replication enabled
ENV STARTUP_BACKGROUND_OPTS=""

#-- Files tailed once container has started
ENV TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/datagovernance-pap.log"

#-- Hostname used for the REST API
ENV REST_API_HOSTNAME="localhost"

#-- Define shared secret between PDG and PAP
ENV DECISION_POINT_SHARED_SECRET="2FederateM0re"

EXPOSE ${HTTPS_PORT}

COPY --from=final-staging ["/","/"]

#- ## Running a PingDataGovernance PAP container
#- To run a PingDataGovernance PAP container: 
#- 
#- ```she   ll
#-   docker run \
#-            --name pingdatagovernancepap \
#-            --publish 8443:443 \
#-            --detach \
#-            pingidentity/pingdatagovernancepap:edge
#- ```
#- 
#- Follow Docker logs with:
#- 
#- ```
#- docker logs -f pingdatagovernancepap
#- ```
#- 
#- Log in with: 
#- * https://localhost:8443/
#-   * Username: admin
#-   * Password: password123