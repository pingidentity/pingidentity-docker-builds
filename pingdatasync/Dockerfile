FROM pingidentity/pingdownloader as staging
ARG PRODUCT=pingdatasync
ARG VERSION=7.2.0.1

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} && \
    unzip /tmp/product.zip -d /tmp/ && \
    cd /tmp/PingDataSync && \
	rm -rf \
		bin/start-sync-server \
		bin/stop-sync-server \
	    docs \
	    bat \
	    *.bat \
	    uninstall \
	    webapps \
	    resource/*.zip \
	    lib/*.bat \
	    lib/*.exe \
	    lib/*.dll && \
	mv /tmp/PingDataSync /opt/server && \
	mkdir -p /opt/tests
COPY _script-util.sh /opt/server/lib/
COPY entrypoint.sh /opt
COPY liveness.sh /opt
COPY preStop.sh /opt
COPY configure-tools.sh /opt
COPY wait-for /opt
COPY utils.sh /opt
COPY build.test.sh /opt/tests

FROM openjdk:8-jre-alpine as pingdatasync
LABEL	maintainer=devops_program@pingidentity.com \
		license="Ping Identity Proprietary" \
		vendor="Ping Identity Corp." \
		name="Ping Identity PingDataSync (Alpine/OpenJDK8) Image"
		
# These are exposed as environment variables to the running containers. 
# They may be overridden externally by "docker run" or some other 
# orchestration framework like Kubernetes.
ENV OUT_DIR="/opt/out"
ENV IN_DIR="/opt/in"

ENV SERVER_ROOT_DIR="${OUT_DIR}/instance"
ENV SECRETS_DIR=/usr/local/secrets
ENV KEY_FILE_NAME=PingDirectory.lic
ENV LICENSE_KEY_FILE=${IN_DIR}/${KEY_FILE_NAME}

ENV SERVER_PROFILE_URL=""
ENV SERVER_PROFILE_BRANCH=""
ENV SERVER_PROFILE_PATH=""

ENV LOCATION=Austin
ENV MAX_HEAP_SIZE=384m

ENV LDAP_PORT=389
ENV LDAPS_PORT=636
ENV HTTPS_PORT=443

ENV TAIL_LOG_FILES="sync"

ENV ROOT_USER_DN="cn=administrator"

ENV ROOT_PASSWORD_FILE_NAME=root-user-password
ENV ROOT_USER_PASSWORD_FILE="${SECRETS_DIR}/${ROOT_PASSWORD_FILE_NAME}"

ENV PATH="${SERVER_ROOT_DIR}/bin:${PATH}"

# Allow input and output directories to be mounted as volumes
VOLUME "${OUT_DIR}"
VOLUME "${IN_DIR}"

RUN apk --no-cache add git curl ca-certificates \
    && apk add --update libintl \
    && apk add --virtual build_deps gettext \
    && cp /usr/bin/envsubst /usr/local/bin/envsubst \
    && apk del build_deps

COPY --from=staging /opt /opt

WORKDIR "${OUT_DIR}"

ENTRYPOINT [ "/opt/entrypoint.sh" ]
CMD [ "start-server" ]