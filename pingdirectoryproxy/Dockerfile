#- # Ping Identity DevOps Docker Image - `pingdirectoryproxy`
#- 
#- This docker image includes the Ping Identity PingDirectoryProxy product binaries
#- and associated hook scripts to create and run a PingDirectoryProxy instance or 
#- instances.
#-
#- ## Related Docker Images
#- - pingidentity/pingbase - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://pingidentity-devops.gitbook.io/devops/docker-images/pingbase)**
#- - pingidentity/pingdatacommon - Common PingData files (i.e. hook scripts)
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
ENV PING_PRODUCT=PingDirectoryProxy
#-- Name of License File
ENV LICENSE_FILE_NAME=PingDirectory.lic
#-- Shortname used when retrieving license from License Server
ENV LICENSE_SHORT_NAME=PD
#-- Version used when retrieving license from License Server
ENV LICENSE_VERSION=${LICENSE_VERSION}

#-- Replication administrative user
ENV ADMIN_USER_NAME=admin

ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server"

#-- Public hostname of the DA app
ENV PD_DELEGATOR_PUBLIC_HOSTNAME=localhost

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
ENV TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/access \
    ${SERVER_ROOT_DIR}/logs/errors \
    ${SERVER_ROOT_DIR}/logs/failed-ops \
    ${SERVER_ROOT_DIR}/logs/config-audit.log \
    ${SERVER_ROOT_DIR}/logs/tools/*.log* \
    ${SERVER_BITS_DIR}/logs/tools/*.log*"

ENV PD_PROFILE="${STAGING_DIR}/pd.profile"

EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT} 5005

COPY --from=final-staging ["/","/"]

#- ## Running a PingDirectoryProxy container
#-
#- The easiest way to test test a simple standalone image of PingDirectoryProxy is to cut/paste the following command into a terminal on a machine with docker.
#- 
#- ```
#-   docker run \
#-            --name pingdirectoryproxy \
#-            --publish 1389:389 \
#-            --publish 8443:443 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingdirectoryproxy \
#-           pingidentity/pingdirectoryproxy:edge
#- ```
#- 
#- You can view the Docker logs with the command:
#- 
#- ```
#-   docker logs -f pingdirectoryproxy
#- ```
#- 
#- You should see the ouptut from a PingDirectoryProxy install and configuration, ending with a message the the PingDirectoryProxy has started.  After it starts, you will see some typical access logs.  Simply ``Ctrl-C`` afer to stop tailing the logs.
#- 
#- ## Running a sample 100/sec search rate test
#- With the PingDirectoryProxy running from the pevious section, you can run a ``searchrate`` job that will send load to the directory at a rate if 100/sec using the following command.
#- 
#- ```
#- docker exec -it pingdirectoryproxy \
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
#-   docker container stop pingdirectoryproxy
#- ```
#- 
#- To remove the container:
#- 
#- ```
#-   docker container rm -f pingdirectoryproxy
#- ```
