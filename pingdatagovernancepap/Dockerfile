#- # Ping Identity DevOps Docker Image - `pingdatagovernancepap`
#- 
#- This docker image includes the Ping Identity PingDataGovernance PAP product binaries
#- and associated hook scripts to create and run a PingDataGovernance PAP instance.
#-
#- ## Related Docker Images
#- - `tomcat:8-jre8-alpine` - Tomcat engine to serve PingDataConsole .war file
#-
ARG SHIM=alpine

FROM pingidentity/pingdownloader as staging
ARG PRODUCT=pingdatagovernancepap
ARG VERSION=8.0.0.0


# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip /tmp/product.zip -d /tmp/ \
    && mkdir /opt/out \
	&& mv /tmp/PingDataGovernance-PAP /opt/server 
COPY [ "liveness.sh", "/opt/" ]
COPY [ "hooks/","/opt/staging/hooks/" ]


FROM pingidentity/pingbase:${SHIM}
#-- PingIdentity license version
ARG LICENSE_VERSION
#-- Ping product name
ENV PING_PRODUCT=PingDataGovernance-PAP
#- Set License Directory BASE (locaion where we start PAP application)
ENV LICENSE_DIR="${BASE}"
#-- Name of License File
ENV LICENSE_FILE_NAME=PingDataGovernance.lic
#-- Shortname used when retrieving license from License Server
ENV LICENSE_SHORT_NAME=PG
#-- Version used when retrieving license from License Server
ENV LICENSE_VERSION=${LICENSE_VERSION}

#-- Minimal Heap size required for Ping DataGovernance
ENV MAX_HEAP_SIZE=384m

ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/admin-point-application/bin/admin-point-application"

#-- Adding lockdown mode so non administrive connections be made until server
#-- has been started with replication enabled
ENV STARTUP_FOREGROUND_OPTS="server ${SERVER_ROOT_DIR}/config/configuration.yml"

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

COPY --from=pingidentity/pingcommon /opt ${BASE}
COPY --from=staging /opt ${BASE}

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
