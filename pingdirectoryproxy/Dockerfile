# Default to Alpine
ARG SHIM=alpine

FROM pingidentity/pingdownloader as staging
ARG PRODUCT=pingdirectoryproxy
ARG VERSION=7.2.1.0

# copy the product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip /tmp/product.zip -d /tmp/ \
    && cd /tmp/PingDirectoryProxy \
	&& find /tmp -type f \( -iname \*.bat -o -iname \*.dll -o -iname \*.exe \) -exec rm -f {} \; \
	&& rm -rf \
		bin/start-proxy \
		bin/stop-proxy \
	    docs \
	    bat \
	    uninstall \
	    webapps \
	    resource/*.zip \
	&& mv /tmp/PingDirectoryProxy /opt/server 
COPY [ "liveness.sh", "/opt/" ]
COPY [ "hooks/","/opt/staging/hooks/" ]

#
# The final image
#
FROM pingidentity/pingbase:${SHIM}
ENV LICENSE_FILE_NAME=PingDirectory.lic
ENV LICENSE_SHORT_NAME=PD
ENV LICENSE_VERSION=7.2
# This is a candidate to move to pingbase
ENV REPLICATION_PORT=8989
ENV PING_PRODUCT="PingDirectoryProxy"
EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT} 5005
# the replication administrative user
ENV ADMIN_USER_NAME="admin"
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server"
ENV STARTUP_FOREGROUND_OPTS="--nodetach"
ENV ROOT_USER_PASSWORD_FILE="${SECRETS_DIR}/root-user-password"
ENV ADMIN_USER_PASSWORD_FILE="${SECRETS_DIR}/admin-user-password"
ENV ENCRYPTION_PASSWORD_FILE="${SECRETS_DIR}/encryption-password"
ENV TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/access"
ENV MAKELDIF_USERS=0
COPY --from=pingidentity/pingdatacommon /opt ${BASE}
COPY --from=staging /opt ${BASE}
