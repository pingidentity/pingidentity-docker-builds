FROM pingidentity/pingdownloader as staging
# place the software being delivered in a conspicuous, unix-correct location
RUN mkdir /opt
WORKDIR /opt
ARG PRODUCT
ARG VERSION

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} && \
    unzip /tmp/product.zip -d /tmp/ && \
    cd /tmp/PingDirectoryProxy && \
	rm -rf \
	    docs \
	    bat \
	    *.bat \
	    uninstall \
	    webapps \
	    resource/*.zip \
	    lib/*.bat \
	    lib/*.exe \
	    lib/wrapper.dll && \
	mv /tmp/PingDirectoryProxy /opt/server
COPY _script-util.sh /opt/server/lib/
COPY entrypoint.sh /opt
COPY liveness.sh /opt
COPY postStart.sh /opt
COPY preStop.sh /opt
COPY configure-tools.sh /opt
COPY externalserversetup.sh /opt

FROM openjdk:8-jre-alpine as pingdirectory
# These are exposed as environment variables to the running containers. 
# They may be overridden externally by "docker run" or some other 
# orchestration framework like Kubernetes.
ENV OUT_DIR=/opt/out
ENV IN_DIR=/opt/in

ENV SERVER_ROOT_DIR="${OUT_DIR}/instance"
ENV SECRETS_DIR=/usr/local/secrets
ENV LICENSE_KEY_FILE="${SECRETS_DIR}/PingDirectory.lic"

ENV LOCATION=Austin
ENV USER_BASE_DN=dc=example,dc=com
ENV MAX_HEAP_SIZE=384m

ENV LDAP_PORT=389
ENV LDAPS_PORT=636
ENV HTTPS_PORT=443

ENV ROOT_USER_DN="cn=administrator"

ENV ROOT_USER_PASSWORD_FILE="${SECRETS_DIR}/root-user-password"

ENV PATH="${SERVER_ROOT_DIR}/bin:${PATH}"

# Override this variable when running the built image to specify number of ds replicas
ENV NUM_DS_REPLICAS=2

# Allow input and output directories to be mounted as volumes
VOLUME "${OUT_DIR}"
VOLUME "${IN_DIR}"

RUN apk --no-cache add git curl ca-certificates

WORKDIR "${OUT_DIR}"

ENTRYPOINT ["/opt/entrypoint.sh"]

CMD ["start-server"]