FROM pingidentity/pingdownloader as staging
ARG PRODUCT=pingdatasync
ARG VERSION=7.2.1.0

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
FROM pingidentity/pingbase
EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT}
ENV TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/sync"
ENV LICENSE_FILE_NAME="PingDirectory.lic"
ENV PING_PRODUCT=PingDataSync
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server"
ENV STARTUP_FOREGROUND_OPTS="--nodetach"
ENV ROOT_USER_PASSWORD_FILE="${SECRETS_DIR}/root-user-password"
COPY --from=pingidentity/pingdatacommon "/opt" "${BASE}"
COPY --from=staging "/opt" "${BASE}"