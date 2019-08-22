#- # Ping Identity DevOps Docker Image - `pingdatagovernance`
#- 
#- This docker image includes the Ping Identity PingDataGovernance product binaries
#- and associated hook scripts to create and run a PingDataGovernance instance or 
#- instances.
#-
#- ## Related Docker Images
#- - pingidentity/pingbase - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://pingidentity-devops.gitbook.io/devops/docker-images/pingbase)**
#- - pingidentity/pingdatacommon - Common PingData files (i.e. hook scripts)
#- - pingidentity/pingdownloader - Used to download product bits
#-
ARG SHIM=alpine

FROM pingidentity/pingdownloader as staging
ARG PRODUCT=pingdatagovernance
ARG VERSION=7.3.0.0

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip /tmp/product.zip -d /tmp/ \
	&& find /tmp -type f \( -iname \*.bat -o -iname \*.dll -o -iname \*.exe \) -exec rm -f {} \; \
    && cd /tmp/PingDataGovernance \
	&& rm -rf \
		bin/start-ds \
		bin/stop-ds \
	    docs \
	    uninstall \
	    webapps \
	    resource/*.zip \
	&& mv /tmp/PingDataGovernance /opt/server 
COPY [ "liveness.sh", "/opt/" ]
COPY [ "hooks/","/opt/staging/hooks/" ]


FROM pingidentity/pingbase:${SHIM}

#-- Ping product name
ENV PING_PRODUCT=PingDataGovernance
#-- Name of License File
ENV LICENSE_FILE_NAME=PingDataGovernance.lic
#-- Shortname used when retrieving license from License Server
ENV LICENSE_SHORT_NAME=PG
#-- Version used when retrieving license from License Server
ENV LICENSE_VERSION=7.3

ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server"

#-- Adding lockdown mode so non administrive connections be made until server
#-- has been started with replication enabled
ENV STARTUP_FOREGROUND_OPTS="--nodetach"

#-- Adding lockdown mode so non administrive connections be made until server
#-- has been started with replication enabled
ENV STARTUP_BACKGROUND_OPTS=""

ENV ROOT_USER_PASSWORD_FILE=${SECRETS_DIR}/root-user-password
ENV ENCRYPTION_PASSWORD_FILE=${SECRETS_DIR}/encryption-password
#-- Files tailed once container has started
ENV TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/access"

EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT} 5005

COPY --from=pingidentity/pingdatacommon /opt ${BASE}
COPY --from=staging /opt ${BASE}

#- ## Running a PingDataGovernance container
#-
#- The easiest way to test test a simple standalone image of PingDataGovernance is to cut/paste the following command into a terminal on a machine with docker.
#- 
#- ```
#-   docker run \
#-            --name pingdatagovernance \
#-            --publish 1389:389 \
#-            --publish 8443:443 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingdatagovernance \
#-           pingidentity/pingdatagovernance:edge
#- ```
#- 
#- You can view the Docker logs with the command:
#- 
#- ```
#-   docker logs -f pingdatagovernance
#- ```
#- 
#- You should see the ouptut from a PingDataGovernance install and configuration, ending with a message the the PingDataGovernance has 
#- started.  After it starts, you will see some typical access logs.  Simply ``Ctrl-C`` afer to stop tailing the logs.
#- 
#- 
#- ## Connection with a REST Client
#- Connection a REST client from Postman or a browser using the default ports and credentials.  The
#- following url will provie a list of all SCIM2 schemas available.  It will be empty until 
#- some resoruces are configured.
#- 
#- |                 |                                   |
#- | --------------: | --------------------------------- |
#- | URL             | https://localhost:8443/scim/v2/Schemas |
#- | Username        | cn=administrator                  |
#- | Password        | 2FederateM0re                     |
#- 
#- ## Stopping/Removing the container
#- To stop the container:
#- 
#- ```
#-   docker container stop pingdatagovernance
#- ```
#- 
#- To remove the container:
#- 
#- ```
#-   docker container rm -f pingdatagovernance
#- ```

