#- # Ping Identity DevOps Docker Image - `pingtoolkit`
#-
#- This docker image includes the Ping Identity PingToolkit
#- and associated hook scripts to create a container that can pull in a SERVER_PROFILE
#- run scripts.  The typical use case of this image would be an init container or a pod/container
#- to perform tasks aside a running set of pods/containers.
#-
#- ## Related Docker Images
#- - `pingbase-java` (Ping-provided base image) - Parent Image
#-

#################################################################################

# Top level ARGS used in all FROM commands
ARG ARCH
# Base image adoption: CI passes BASE_IMAGE (+ JAVA_LINK for JVM
# products). Production CI fail-fasts on unmapped jvm ids before ever
# reaching here.
ARG BASE_IMAGE
ARG JAVA_LINK

#################################################################################

FROM ${BASE_IMAGE} AS final-staging

# Ping-provided base images end at USER 9031:0; staging RUN steps run as root.
USER 0:0
# The Ping-provided alpine base ships tini at /sbin/tini (same path the ENTRYPOINT uses).
# Re-declared: top-level ARGs are not inherited into stage RUN scope.
ARG JAVA_LINK
# Preserve the JAVA_HOME=/opt/java contract (pingbase env + PATH); the link
# target lives inside the Ping-provided base image.
RUN if test -n "${JAVA_LINK}"; then ln -s "${JAVA_LINK}" /opt/java; fi

# get Ping-wide common scripts from the build context (the old
# pingcommon carrier image is retired — plain build inputs now)
COPY ["runtime/common/","/opt/"]

# apply product-specific hooks and patches
COPY ["pingtoolkit/opt","/opt"]

# Run build
RUN ["/opt/build.sh"]

#################################################################################

# The final image (Ping-provided base image — PDI-2522/2523 final-stage unification; the v1
# pingbase env-carrier stage is retired, so the env vars it used to supply
# to the hook framework (BASE/HOOKS_DIR/STAGING_DIR/PATH/...) are re-declared
# below).
FROM ${BASE_IMAGE}

# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
ARG DATE
ARG VERSION

# from pingbase
ARG BASE
ENV BASE=${BASE:-/opt} \
    JAVA_HOME=/opt/java
#-- Path to the staging area where the remote and local server profiles
#-- can be merged
ENV STAGING_DIR=${BASE}/staging \
#-- Path to the runtime volume
    OUT_DIR=${BASE}/out
#-- Path from which the runtime executes
ENV SERVER_ROOT_DIR=${OUT_DIR}/instance
#-- Location of a local server-profile volume
ENV IN_DIR=${BASE}/in \
#-- Path to the server bits
    SERVER_BITS_DIR=${BASE}/server \
#-- Path to a volume generically used to export or backup data
    BAK_DIR=${BASE}/backup \
#-- Path to a volume generically used for logging
    LOGS_DIR=${BASE}/logs \

#-- Path to a manifest of files expected in the staging dir on first image startup
    STAGING_MANIFEST=${BASE}/staging-manifest.txt \
#-- Whether to clean the staging dir when the image starts
    CLEAN_STAGING_DIR=false \
#-- Default path to the secrets
    SECRETS_DIR=/run/secrets \
#-- Path to the topology file
    TOPOLOGY_FILE=${STAGING_DIR}/topology.json \
#-- Path where all the hooks scripts are stored
    HOOKS_DIR=${STAGING_DIR}/hooks \
#-- Environment Property file use to share variables between scripts in container
    CONTAINER_ENV=${STAGING_DIR}/.env \

#-- Path where the remote server profile is checked out or cloned before
#-- being staged prior to being applied on the runtime
    SERVER_PROFILE_DIR=/tmp/server-profile \
#-- A valid git HTTPS URL (not ssh)
    SERVER_PROFILE_URL="" \
#-- When set to "true", the server profile git URL will not be printed to container output.
    SERVER_PROFILE_URL_REDACT=true \
#-- A valid git branch (optional)
    SERVER_PROFILE_BRANCH="" \
#-- The subdirectory in the git repo
    SERVER_PROFILE_PATH="" \
#-- Whether to update the server profile upon container restart
    SERVER_PROFILE_UPDATE="false" \

#-- Requires strict checks on security
    SECURITY_CHECKS_STRICT=false \
#-- Perform a check for filenames that may violate security (i.e. secret material)
    SECURITY_CHECKS_FILENAME="*.jwk *.pin" \

#-- If this is set to true, then the container will provide a hard warning and continue.
    UNSAFE_CONTINUE_ON_ERROR="" \

#-- File name for devops-creds passed as a Docker secret (sourced from
#-- /run/secrets by pingcommon.lib.sh at source time)
    PING_IDENTITY_DEVOPS_FILE=devops-secret \
#-- Legal requirement to explicitly accept the terms of the PingIdentity License
#-- (v1 pingbase carrier default; 17-check-license.sh reads it)
    PING_IDENTITY_ACCEPT_EULA=NO \

#-- Redacts PING_IDENTITY_DEVOPS_KEY in 04-check-variables.sh output
    PING_IDENTITY_DEVOPS_KEY_REDACT=true \

#-- License directory
    LICENSE_DIR="${SERVER_ROOT_DIR}" \
#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="tail" \
#-- The command-line options to provide to the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="-f /dev/null" \
#-- The command-line options to provide to the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
    STARTUP_BACKGROUND_OPTS="" \

#-- A whitespace separated list of log files to tail to the container
#-- standard output - DO NOT USE WILDCARDS like /path/to/logs/*.log
    TAIL_LOG_FILES="" \

#-- If 'true', the output logs will be colorized with GREENs and REDs,
#-- otherwise, no colorization will be done.  This is good for tools
#-- that monitor logs and colorization gets in the way.
    COLORIZE_LOGS=true \

#-- Location default value
    LOCATION=Docker \
#-- Validation toggle for LOCATION: true to require any string denoting a
#-- logical/physical location, false to disable the check
    LOCATION_VALIDATION=true \

#-- Triggers verbose messages in scripts using the set -x option.
    VERBOSE=false \
#-- Set the server in debug mode, with increased output
    PING_DEBUG=false \
#-- The name of Ping product, i.e. PingFederate, PingDirectory
    PING_PRODUCT="PingToolkit" \
#-- Validation toggle for PING_PRODUCT: true to require a valid Ping product
#-- type (e.g. PingFederate,PingDirectory), false to disable the check
    PING_PRODUCT_VALIDATION=true \

# Image version and git revision, set by build process of the docker build
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
    DATE=${DATE} \
    PING_PRODUCT_VERSION=${VERSION} \
#-- Default shell prompt (i.e. productName:hostname:workingDir)
    PS1="\${PING_PRODUCT}:\h:\w\n> " \

#-- PATH used by the container
    PATH="${JAVA_HOME}/bin:${BASE}:${SERVER_ROOT_DIR}/bin:${PATH}"

# WORKDIR parity with the v1 env-carrier (WORKDIR /opt): the Ping-provided base sets /
# (PDI-2522). The ENTRYPOINT above is absolute either way, but exec/interactive
# sessions kept the /opt default.
WORKDIR ${BASE}

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL name="${PING_PRODUCT}" \
      version="${IMAGE_VERSION}" \
      release="${IMAGE_GIT_REV}" \
      date="${DATE}" \
      summary="PingToolKit creates a container that can pull in a SERVER_PROFILE run scripts." \
      description="PingToolKit creates a container that can pull in a SERVER_PROFILE run scripts."

# Explicit entrypoint chain (PDI-2522, /sbin/tini per PDI-2523): the v1
# pingbase env-carrier stage used to supply `ENTRYPOINT ["./bootstrap.sh"]`.
# Absolute paths — the Ping-provided base's WORKDIR is /, not /opt. /sbin/tini (0.19.0)
# ships in the Ping-provided base itself; bootstrap.sh no longer execs a tini of its own.
ENTRYPOINT ["/sbin/tini", "--", "/opt/bootstrap.sh"]
CMD ["start-server"]

# Legal pointer (was shipped by the v1 pingbase carrier as /licenses/license.txt;
# re-homed to the build context for the Ping-provided base image, which ships no /licenses).
# Same source as the other products — avoid a per-product fork drifting.
COPY ["legal/license.txt", "/licenses/license.txt"]

COPY --from=final-staging ["/","/"]
