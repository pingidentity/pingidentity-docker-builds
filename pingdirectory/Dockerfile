FROM pingidentity/pingdownloader as staging
ARG PRODUCT=pingdirectory
ARG VERSION=7.2.0.1

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} && \
    unzip /tmp/product.zip -d /tmp/ && \
    cd /tmp/PingDirectory && \
	rm -rf \
		bin/start-ds \
		bin/stop-ds \
	    docs \
	    bat \
	    *.bat \
	    uninstall \
	    webapps \
	    resource/*.zip \
	    lib/*.bat \
	    lib/*.exe \
	    lib/wrapper.dll && \
	mv /tmp/PingDirectory /opt/server && \
	mkdir -p /opt/backup
COPY _script-util.sh /opt/server/lib/
COPY entrypoint.sh /opt
COPY liveness.sh /opt
COPY postStart.sh /opt
COPY preStop.sh /opt
COPY configure-tools.sh /opt
COPY utils.sh /opt
COPY wait-for /opt

FROM openjdk:8-jre-alpine as pingdirectory
# These are exposed as environment variables to the running containers. 
# They may be overridden externally by "docker run" or some other 
# orchestration framework like Kubernetes.
ENV OUT_DIR=/opt/out
ENV IN_DIR=/opt/in

ENV SERVER_ROOT_DIR="${OUT_DIR}/instance"
ENV SECRETS_DIR=/usr/local/secrets
ENV KEY_FILE_NAME=PingDirectory.lic
ENV LICENSE_KEY_FILE=${IN_DIR}/${KEY_FILE_NAME}

ENV SERVER_PROFILE_URL=""
ENV SERVER_PROFILE_BRANCH=""
ENV SERVER_PROFILE_PATH=""

ENV LOCATION=Docker
ENV USER_BASE_DN=dc=example,dc=com
ENV MAX_HEAP_SIZE=384m

ENV LDAP_PORT=389
ENV LDAPS_PORT=636
ENV HTTPS_PORT=443
ENV JMX_PORT=689
ENV REPLICATION_PORT=8989

EXPOSE ${LDAP_PORT}
EXPOSE ${LDAPS_PORT}
EXPOSE ${HTTPS_PORT}
EXPOSE ${JMX_PORT}
EXPOSE 5005

ENV ROOT_USER_DN="cn=administrator"
ENV ADMIN_USER_NAME=admin

ENV ROOT_USER_PASSWORD_FILE=${SECRETS_DIR}/root-user-password
ENV ADMIN_USER_PASSWORD_FILE=${SECRETS_DIR}/admin-user-password
ENV ENCRYPTION_PASSWORD_FILE=${SECRETS_DIR}/encryption-password

ENV PING_DEBUG=""

ENV TAIL_LOG_FILES="access"

ENV PATH="${SERVER_ROOT_DIR}/bin:${PATH}"

# Allow input and output directories to be mounted as volumes
VOLUME "${OUT_DIR}"
VOLUME "${IN_DIR}"
VOLUME /opt/backup

RUN apk --no-cache add git curl ca-certificates jq \
    && apk add --update libintl \
    && apk add --virtual build_deps gettext \
    && cp /usr/bin/envsubst /usr/local/bin/envsubst \
    && apk del build_deps
	
COPY --from=staging /opt /opt

WORKDIR "${OUT_DIR}"

ENTRYPOINT [ "/opt/entrypoint.sh" ]

CMD [ "start-server" ]