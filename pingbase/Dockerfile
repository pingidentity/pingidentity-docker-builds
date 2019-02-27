FROM openjdk:8-jre-alpine
ONBUILD LABEL	maintainer=devops_program@pingidentity.com \
		license="Ping Identity Proprietary" \
		vendor="Ping Identity Corp." \
		name="Ping Identity (Alpine/OpenJDK8) Image"
ONBUILD RUN apk --no-cache add git curl ca-certificates jq \
    && apk add --update libintl \
    && apk add --virtual build_deps gettext \
    && cp /usr/bin/envsubst /usr/local/bin/envsubst \
    && apk del build_deps \
    && mkdir -p ${BASE}/tests
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
# the default path to the secrets
ONBUILD ENV SECRETS_DIR=/usr/local/secrets

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
# the command-line options to provide to the the startup command
# when the container starts with the server in the foreground
# This is the normal start flow for the container
ONBUILD ENV STARTUP_FOREGROUND_OPTS=""
# the command-line options to provide to the the startup command
# when the container starts with the server in the background
# This is the debug start flow for the container
ONBUILD ENV STARTUP_BACKGROUND_OPTS=""

# a whitespace separated list of log files to tail to the container standard output
ONBUILD ENV TAIL_LOG_FILES=""

# the location default value
ONBUILD ENV LOCATION=Docker

# the heap size (for java products)
ONBUILD ENV MAX_HEAP_SIZE=384m

ONBUILD ENV JVM_TUNING="AGGRESSIVE"

# this variable indicates to set the server in debug mode
ONBUILD ENV PING_DEBUG="false"

# the name of Ping product
# this can be useful for displaying or sending user messages
# or branching programmatically
ONBUILD ENV PING_PRODUCT ""

# the port over which to communicate for LDAP
ONBUILD ENV LDAP_PORT=389
# the port over which to communicate for LDAPS
ONBUILD ENV LDAPS_PORT=636
# the port over which to communicate for HTTPS
ONBUILD ENV HTTPS_PORT=443
# the port for monitoring over JMX protocol
ONBUILD ENV JMX_PORT=689

ONBUILD ENV TOPOLOGY_SIZE=1
ONBUILD ENV TOPOLOGY_PREFIX=""
ONBUILD ENV TOPOLOGY_SUFFIX=""

# the default administrative user for PingData
ONBUILD ENV ROOT_USER_DN="cn=administrator"

ONBUILD ENV PATH="${SERVER_ROOT_DIR}/bin:${PATH}"

# the method by which the framework can assess whether the container is viable or not
ONBUILD HEALTHCHECK --interval=31s --timeout=30s --start-period=120s --retries=3 CMD [ "${BASE}/liveness.sh" ]

ONBUILD VOLUME [ "${BAK_DIR}", "${IN_DIR}", "${OUT_DIR}" ]
ONBUILD WORKDIR ${BASE}
### WARNING THE ENTRYPOINT WILL NEED TO BE UPDATED MANUALLY IF THE BASE IS CHANGED
### IT DOES NOT EXPAND VARIABLES -- REAL BUMMER
ONBUILD ENTRYPOINT [ "/opt/entrypoint.sh" ]
ONBUILD CMD [ "start-server" ]