#- # Ping Identity DevOps Docker Image - `pingdirectory`
#- 
#- This docker image includes the Ping Identity PingDirectory product binaries
#- and associated hook scripts to create and run a PingDirectory instance or 
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
ARG PRODUCT=pingdirectory
ARG VERSION=7.3.0.0

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip /tmp/product.zip -d /tmp/ \
	&& find /tmp -type f \( -iname \*.bat -o -iname \*.dll -o -iname \*.exe \) -exec rm -f {} \; \
    && cd /tmp/PingDirectory \
	&& rm -rf \
		bin/start-ds \
		bin/stop-ds \
	    docs \
	    uninstall \
	    webapps \
	    resource/*.zip \
	&& mv /tmp/PingDirectory /opt/server 
COPY [ "liveness.sh", "/opt/" ]
COPY [ "hooks/","/opt/staging/hooks/" ]


FROM pingidentity/pingbase:${SHIM}

#-- Ping product name
ENV PING_PRODUCT=PingDirectory
#-- Name of License File
ENV LICENSE_FILE_NAME=PingDirectory.lic
#-- Shortname used when retrieving license from License Server
ENV LICENSE_SHORT_NAME=PD
#-- Version used when retrieving license from License Server
ENV LICENSE_VERSION=7.3

#-- Default PingDirectory Replication Port
ENV REPLICATION_PORT=8989
#-- Replication administrative user
ENV ADMIN_USER_NAME=admin

ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server"

#-- Adding lockdown mode so non administrive connections be made until server
#-- has been started with replication enabled
ENV STARTUP_FOREGROUND_OPTS="--nodetach"

#-- Adding lockdown mode so non administrive connections be made until server
#-- has been started with replication enabled
ENV STARTUP_BACKGROUND_OPTS=""

ENV ROOT_USER_PASSWORD_FILE=${SECRETS_DIR}/root-user-password
ENV ADMIN_USER_PASSWORD_FILE=${SECRETS_DIR}/admin-user-password
ENV ENCRYPTION_PASSWORD_FILE=${SECRETS_DIR}/encryption-password
#-- Files tailed once container has started
ENV TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/access"
#-- Number of users to auto-populate using make-ldif templates
ENV MAKELDIF_USERS=0

#-- The default retry timeout in seconds for dsreplication and
#-- remove-defunct-server
ENV RETRY_TIMEOUT_SECONDS=120

EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT} 5005

COPY --from=pingidentity/pingdatacommon /opt ${BASE}
COPY --from=staging /opt ${BASE}

#- ## Running a PingDirectory container
#-
#- The easiest way to test test a simple standalone image of PingDirectory is to cut/paste the following command into a terminal on a machine with docker.
#- 
#- ```
#-   docker run \
#-            --name pingdirectory \
#-            --publish 1389:389 \
#-            --publish 8443:443 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingdirectory \
#-           pingidentity/pingdirectory:edge
#- ```
#- 
#- You can view the Docker logs with the command:
#- 
#- ```
#-   docker logs -f pingdirectory
#- ```
#- 
#- You should see the ouptut from a PingDirectory install and configuration, ending with a message the the PingDirectory has started.  After it starts, you will see some typical access logs.  Simply ``Ctrl-C`` afer to stop tailing the logs.
#- 
#- ## Running a sample 100/sec search rate test
#- With the PingDirectory running from the pevious section, you can run a ``searchrate`` job that will send load to the directory at a rate if 100/sec using the following command.
#- 
#- ```
#- docker exec -it pingdirectory \
#-         /opt/out/instance/bin/searchrate \
#-                 -b dc=example,dc=com \
#-                 --scope sub \
#-                 --filter "(uid=user.[1-9])" \
#-                 --attribute mail \
#-                 --numThreads 2 \
#-                 --ratePerSecond 100
#- ```
#- 
#- ## Connecting with an LDAP Client
#- Connect an LDAP Client (such as Apache Directory Studio) to this container using the default ports and credentials
#- 
#- |                 |                                   |
#- | --------------: | --------------------------------- |
#- | LDAP Port       | 1389 (mapped to 389)              |
#- | LDAP Base DN    | dc=example,dc=com                 |
#- | Root Username   | cn=administrator                  |
#- | Root Password   | 2FederateM0re                     |
#- 
#- ## Connection with a REST Client
#- Connection a REST client from Postman or a browser using the default ports and credentials
#- 
#- |                 |                                   |
#- | --------------: | --------------------------------- |
#- | URL             | https://localhost:8443/scim/Users |
#- | Username        | cn=administrator                  |
#- | Password        | 2FederateM0re                     |
#- 
#- ## Stopping/Removing the container
#- To stop the container:
#- 
#- ```
#-   docker container stop pingdirectory
#- ```
#- 
#- To remove the container:
#- 
#- ```
#-   docker container rm -f pingdirectory
#- ```
