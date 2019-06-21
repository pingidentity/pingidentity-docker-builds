#- # Ping Identity DevOps Docker Image - `pingdatasync`
#- 
#- This docker image includes the Ping Identity PingDataSync product binaries
#- and associated hook scripts to create and run a PingDataSync instance.
#-
#- ## Related Docker Images
#- - pingidentity/pingbase - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://pingidentity-devops.gitbook.io/devops/docker-images/pingbase)**
#- - pingidentity/pingdatacommon - Common PingData files (i.e. hook scripts)
#- - pingidentity/pingdownloader - Used to download product bits
#-

ARG SHIM=alpine

FROM pingidentity/pingdownloader as staging
ARG PRODUCT=pingdatasync
ARG VERSION=7.3.0.0

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip /tmp/product.zip -d /tmp/ \
	&& find /tmp -type f \( -iname \*.bat -o -iname \*.dll -o -iname \*.exe \) -exec rm -f {} \; \
    && cd /tmp/PingDataSync && \
	rm -rf \
		bin/start-sync-server \
		bin/stop-sync-server \
	    docs \
	    bat \
	    uninstall \
	    webapps \
	    resource/*.zip \
	&& mv /tmp/PingDataSync /opt/server 
COPY [ "liveness.sh", "/opt/" ]
COPY [ "hooks/", "/opt/staging/hooks/" ]
COPY [ "build.test.sh", "/opt/tests/" ]

#
# The final image
#
FROM pingidentity/pingbase:${SHIM}

ENV TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/sync"
ENV LICENSE_FILE_NAME="PingDirectory.lic"
ENV LICENSE_SHORT_NAME=PD
ENV LICENSE_VERSION=7.3
ENV PING_PRODUCT=PingDataSync
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server"
ENV STARTUP_FOREGROUND_OPTS="--nodetach"
ENV ROOT_USER_PASSWORD_FILE="${SECRETS_DIR}/root-user-password"

EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT}

COPY --from=pingidentity/pingdatacommon "/opt" "${BASE}"
COPY --from=staging "/opt" "${BASE}"

#- ## Running a PingDataSync container
#- ```
#-   docker run \
#-            --name pingdatasync \
#-            --publish 1389:389 \
#-            --publish 8443:443 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=simple-sync/pingdatasync \
#-            pingidentity/pingdatasync
#- ```
