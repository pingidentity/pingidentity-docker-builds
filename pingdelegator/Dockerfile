FROM pingidentity/pingdownloader as staging
RUN /get-bits.sh -p delegator -v 3.0.2 \
    && unzip /tmp/product.zip -d /tmp \
    && mv /tmp/delegator /opt/server


FROM nginx:stable-alpine as pingdelegatedadmin
LABEL	maintainer=devops_program@pingidentity.com \
		license="Ping Identity Proprietary" \
		vendor="Ping Identity Corp." \
		name="Ping Identity PingDelegatedAdmin (Alpine/OpenJDK8) Image"
EXPOSE 80 443
RUN apk --no-cache add git curl ca-certificates jq \
    && apk add --update libintl \
    && apk add --virtual build_deps gettext \
    && cp /usr/bin/envsubst /usr/local/bin/envsubst \
    && apk del build_deps \
    && mkdir -p ${BASE}/tests
# the image base /might/ be changed at build-time but
# be aware that the entrypoint will have to be
# overridden to reflect the change
ARG BASE
ENV BASE=${BASE:-/opt}
# the path to the local server-profile volume
ENV IN_DIR=${BASE}/in
# the path to the runtime volume
ENV OUT_DIR=${BASE}/out

# the default path to the secrets
ENV SECRETS_DIR=/usr/local/secrets

# the path to the staging area where the remote and local
# server profiles can be merged
ENV STAGING_DIR=${BASE}/staging

# the path where all the hooks scripts are stored
ENV HOOKS_DIR=${STAGING_DIR}/hooks
# the path where the remote server profile is checked out or cloned
# before being staged prior to being applied on the runtime

ENV SERVER_PROFILE_DIR=${BASE}/server-profile
# A valid git HTTPS URL (not ssh)
ENV SERVER_PROFILE_URL=""
# the branch
ENV SERVER_PROFILE_BRANCH=""
# the subdirectory in the repo
ENV SERVER_PROFILE_PATH=""
# whether to update the server profile upon container restart
ENV SERVER_PROFILE_UPDATE="false"
# the path from which the runtime executes
ENV SERVER_ROOT_DIR=${OUT_DIR}/instance
# the command that the entrypoint will execute in the foreground to instantiate the container
ENV STARTUP_COMMAND=""
# the command-line options to provide to the the startup command
# when the container starts with the server in the foreground
# This is the normal start flow for the container
ENV STARTUP_FOREGROUND_OPTS=""
# the command-line options to provide to the the startup command
# when the container starts with the server in the background
# This is the debug start flow for the container
ENV STARTUP_BACKGROUND_OPTS=""

# a whitespace separated list of log files to tail to the container standard output
ENV TAIL_LOG_FILES=""

RUN apk --no-cache add git curl ca-certificates
VOLUME /opt/in
COPY entrypoint.sh /opt
COPY --from=pingidentity/pingdatacommon /opt ${BASE}
RUN rm -f ${HOOKS_DIR}/16-apply-server-profile.sh
COPY --from=staging /opt/server/app /usr/share/nginx/html/delegator
COPY index.html /usr/share/nginx/html/index.html
ENTRYPOINT [ "/opt/entrypoint.sh" ]
CMD ["start-server"]
