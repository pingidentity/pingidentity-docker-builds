#- # Ping Identity DevOps Docker Image - `pingdirectory`
#-
#- This docker image includes the Ping Identity PingDirectory product binaries
#- and associated hook scripts to create and run a PingDirectory instance or
#- instances.
#-
#- ## Related Docker Images
#- - `pingidentity/pingbase` - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)**
#- - `pingidentity/pingdatacommon` - Common Ping files (i.e. hook scripts)
#- - `pingidentity/pingdownloader` - Used to download product bits
#-
ARG PRODUCT
ARG SHIM
ARG SHIM_TAG
ARG VERSION
ARG JVM
ARG REGISTRY
ARG DEPS
ARG GIT_TAG

FROM ${REGISTRY}/${PRODUCT}:staging-${VERSION}-${GIT_TAG} as product-staging
FROM ${REGISTRY}/pingdatacommon:${GIT_TAG} as common
FROM ${REGISTRY}/pingjvm:${JVM}_${SHIM_TAG}-${GIT_TAG} as jvm

FROM ${DEPS}${SHIM} as final-staging
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
# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
# PingIdentity license version
ARG LICENSE_VERSION

ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \

#-- Ping product name
    PING_PRODUCT=PingDirectory \
#-- Name of license File
    LICENSE_FILE_NAME=PingDirectory.lic \
#-- Short name used when retrieving license from License Server
    LICENSE_SHORT_NAME=PD \
#-- Version used when retrieving license from License Server
    LICENSE_VERSION=${LICENSE_VERSION} \

#-- Default PingDirectory Replication Port
    REPLICATION_PORT=8989 \
#-- Replication administrative user
    ADMIN_USER_NAME=admin \

#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server" \

#-- Public hostname of the DA app
    PD_DELEGATOR_PUBLIC_HOSTNAME=localhost \

#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="--nodetach" \

#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
    STARTUP_BACKGROUND_OPTS="" \

#-- Location of file with the root user password (i.e. cn=directory manager).
#-- Defaults to /SECRETS_DIR/root-user-password
    ROOT_USER_PASSWORD_FILE= \

#-- Location of file with the admin password, used as the password replication admin
#-- Defaults to /SECRETS_DIR/admin-user-password
    ADMIN_USER_PASSWORD_FILE= \

#-- Location of file with the passphrase for setting up encryption
#-- Defaults to /SECRETS_DIR/encryption-password
    ENCRYPTION_PASSWORD_FILE= \

#-- Files tailed once container has started
    TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/access ${SERVER_ROOT_DIR}/logs/errors ${SERVER_ROOT_DIR}/logs/failed-ops ${SERVER_ROOT_DIR}/logs/config-audit.log ${SERVER_ROOT_DIR}/logs/tools/*.log* ${SERVER_BITS_DIR}/logs/tools/*.log*" \
#-- Number of users to auto-populate using make-ldif templates
    MAKELDIF_USERS=0 \

#-- The default retry timeout in seconds for dsreplication and
#-- remove-defunct-server
    RETRY_TIMEOUT_SECONDS=180 \

#-- Flag to disable schema replication. In a DevOps environment, schema
#-- comes from configuration. So it does not need to be replicated.
    DISABLE_SCHEMA_REPLICATION=false \

#-- Directory for the profile used by the PingData manage-profile tool
    PD_PROFILE="${STAGING_DIR}/pd.profile" \

#-- Force a rebuild (replace-profile) of a PingDirectoy on restart.
#-- Used when changes are made outside of the PD_PROFILE
    PD_REBUILD_ON_RESTART=false

LABEL image-version="${IMAGE_VERSION}" \
      image-git-rev="${IMAGE_GIT_REV}"

EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT}

COPY --from=final-staging ["/","/"]

#- ## Running a PingDirectory container
#-
#- The easiest way to test test a simple standalone image of PingDirectory is to cut/paste the following command into a terminal on a machine with docker.
#-
#- ```
#-   docker run \
#-            --name pingdirectory \
#-            --publish 1389:1389 \
#-            --publish 8443:1443 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingdirectory \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingdirectory:edge
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
#- With the PingDirectory running from the previous section, you can run a ``searchrate`` job that will send load to the directory at a rate if 100/sec using the following command.
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
#- | LDAP Port       | 1389                              |
#- | LDAP Base DN    | dc=example,dc=com                 |
#- | Root Username   | cn=administrator                  |
#- | Root Password   | 2FederateM0re                     |
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
