FROM pingidentity/pingdownloader as staging
ARG BASE=/opt
ARG PRODUCT=pingdirectory
ARG VERSION=7.2.0.1

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip /tmp/product.zip -d /tmp/ \
	&& find /tmp -type f \( -iname \*.bat -o -iname \*.dll -o -iname \*.exe \) -exec rm -f {} \; \
    && cd /tmp/PingDirectory \
	&& rm -rf \
		bin/start-ds \
		bin/stop-ds \
	    docs \
	    bat \
	    uninstall \
	    webapps \
	    resource/*.zip \
	&& mv /tmp/PingDirectory ${BASE}/server 
COPY [ "liveness.sh", "pingdirectory.lib.sh", "${BASE}/" ]
COPY [ "80-post-start.sh", "183-run-setup.sh","189-import-data.sh","${BASE}/staging/hooks/" ]

#
# The final image
#
FROM pingidentity/pingbase
ENV LICENSE_FILE_NAME=PingDirectory.lic
# This is a candidate to move to pingbase
ENV USER_BASE_DN=dc=example,dc=com
ENV REPLICATION_PORT=8989
ENV PING_PRODUCT=PingDirectory
EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT} 5005
# the replication administrative user
ENV ADMIN_USER_NAME=admin
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server"
ENV STARTUP_FOREGROUND_OPTS="--nodetach"
ENV ROOT_USER_PASSWORD_FILE=${SECRETS_DIR}/root-user-password
ENV ADMIN_USER_PASSWORD_FILE=${SECRETS_DIR}/admin-user-password
ENV ENCRYPTION_PASSWORD_FILE=${SECRETS_DIR}/encryption-password
ENV TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/access"
ENV MAKELDIF_USERS=0
COPY --from=pingidentity/pingdatacommon ${BASE} ${BASE}
COPY --from=staging ${BASE} ${BASE}