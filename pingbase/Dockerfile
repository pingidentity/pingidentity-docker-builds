FROM openjdk:8-jre-alpine
ONBUILD LABEL	maintainer=devops_program@pingidentity.com \
		license="Ping Identity Proprietary" \
		vendor="Ping Identity Corp." \
		name="Ping Identity (Alpine/OpenJDK8) Image"
ONBUILD RUN apk --no-cache add git curl ca-certificates jq \
    && apk add --update libintl \
    && apk add --virtual build_deps gettext \
    && cp /usr/bin/envsubst /usr/local/bin/envsubst \
    && apk del build_deps
# the image base /might/ be changed at build-time but
# be aware that the entrypoint will have to be
# overridden to reflect the change
ONBUILD ARG BASE
ONBUILD ENV BASE=${BASE:-/opt}
# the path to the local server-profile volume
ONBUILD ENV IN_DIR=${BASE}/in
# the path to the runtime volume
ONBUILD ENV OUT_DIR=${BASE}/out
# the path to a volume generically used to export or backup data
ONBUILD ENV BAK_DIR=${BASE}/backup
# the path to the staging area where the remote and local
# server profiles can be merged
ONBUILD ENV STAGING_DIR=${BASE}/staging
# the path where all the hooks scripts are stored
ONBUILD ENV HOOKS_DIR=${STAGING_DIR}/hooks
# the path where the remote server profile is checked out or cloned
# before being staged prior to being applied on the runtime
ONBUILD ENV SERVER_PROFILE_DIR=${BASE}/server-profile
# A valid git HTTPS URL (not ssh)
ONBUILD ENV SERVER_PROFILE_URL=""
# the branch
ONBUILD ENV SERVER_PROFILE_BRANCH=""
# the subdirectory in the repo
ONBUILD ENV SERVER_PROFILE_PATH=""
# whether to update the server profile upon container restart
ONBUILD ENV SERVER_PROFILE_UPDATE="false"
# the path from which the runtime executes
ONBUILD ENV SERVER_ROOT_DIR=${OUT_DIR}/instance
# the command that the entrypoint will execute in the foreground to instantiate the container
ONBUILD ENV STARTUP_COMMAND=""
# a whitespace separated list of log files to tail to the container standard output
ONBUILD ENV TAIL_LOG_FILES=""
# the method by which the framework can assess whether the container is viable or not
ONBUILD HEALTHCHECK --interval=31s --timeout=30s --start-period=120s --retries=3 CMD [ "${BASE}/liveness.sh" ]
ONBUILD ENV PATH="${SERVER_ROOT_DIR}/bin:${PATH}"
ONBUILD VOLUME [ "${BAK_DIR}", "${IN_DIR}", "${OUT_DIR}" ]
ONBUILD WORKDIR ${BASE}
### WARNING THE ENTRYPOINT WILL NEED TO BE UPDATED MANUALLY IF THE BASE IS CHANGED
### IT DOES NOT EXPAND VARIABLES -- REAL BUMMER
ONBUILD ENTRYPOINT [ "/opt/entrypoint.sh" ]
ONBUILD CMD [ "start-server" ]