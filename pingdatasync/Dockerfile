FROM pingidentity/pingdownloader as staging
ARG BASE=/opt
ARG PRODUCT=pingdatasync
ARG VERSION=7.2.0.1

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
	&& mv /tmp/PingDataSync ${BASE}/server 
COPY [ "liveness.sh", "${BASE}/" ]
COPY [ "183-run-setup.sh", "${BASE}/staging/hooks/" ]
COPY [ "build.test.sh", "${BASE}/tests/" ]

#
# The final image
#
FROM pingidentity/pingbase
EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT}
ENV TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/sync"
ENV LICENSE_FILE_NAME="PingDirectory.lic"
ENV PING_PRODUCT=PingDirectory
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server"
ENV STARTUP_FOREGROUND_OPTS="--nodetach"
ENV ROOT_USER_PASSWORD_FILE="${SECRETS_DIR}/root-user-password"
COPY --from=pingidentity/pingdatacommon ${BASE} ${BASE}
COPY --from=staging ${BASE} ${BASE}