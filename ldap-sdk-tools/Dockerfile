#- # Ping Identity Docker Image - `ldap-sdk-tools`
#-
#- This docker image provides an alpine image with the LDAP Client
#- SDK tools to be used against other PingDirectory instances.
#-
#- ## Related Docker Images
#- - `pingbase-java` (v2 base) - Parent Image
#- - `pingcommon` - Common Ping files (i.e. hook scripts)
#-

#################################################################################

# Top level ARGS used in all FROM commands
ARG ARCH
# Keep DEPS: the alpine product-staging stage downloads product bits through
# the deps pull-through registry.
ARG DEPS
# v2 base adoption: CI passes V2_BASE_IMAGE (+ JAVA_LINK for JVM
# products). Production CI fail-fasts on unmapped jvm ids before ever
# reaching here.
ARG V2_BASE_IMAGE
ARG JAVA_LINK

#################################################################################

# Always use alpine to download product bits (pinned here: the
# LATEST_ALPINE_VERSION build-arg was retired with the carrier-image
# mechanics in PDI-2523 — keep this pin in sync with build_foundation.sh
# and the alpine shim pins in the versions.json files).
FROM ${DEPS}alpine:3.24.2 AS product-staging

# ARGS used in get-product-bits.sh RUN command
ARG PRODUCT
ARG VERSION
ARG ARTIFACTORY_URL
ARG VERBOSE

#Add wait-for
COPY ["ldap-sdk-tools/wait-for","/opt/"]

# Get Ping-wide common scripts from the build context (PDI-2523 carrier
# elimination: pingcommon is no longer built as an image).
COPY ["pingcommon/opt/get-product-bits.sh","/opt/get-product-bits.sh"]

# Download the product bits
RUN /opt/get-product-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip -q /tmp/product.zip -d /tmp/ \
        -x *.bat \
        -x *.dll \
        -x *.exe \
        -x *.ini \
        -x */src.zip \
        -x */android-ldap-client/* \
        -x */docs/* \
    && mv /tmp/unboundid-ldapsdk-*/tools /opt/ \
    && mv /tmp/unboundid-ldapsdk-*/LICENSE* /opt/ \
    && mv /tmp/unboundid-ldapsdk-*/unboundid-ldapsdk.jar /opt/

#################################################################################

FROM ${V2_BASE_IMAGE} AS final-staging

# v2 base images end at USER 9031:0; staging RUN steps run as root.
USER 0:0
# v2 alpine base ships tini at /sbin/tini (same path the ENTRYPOINT uses).
# Re-declared: top-level ARGs are not inherited into stage RUN scope.
ARG JAVA_LINK
# Preserve the JAVA_HOME=/opt/java contract (pingbase env + PATH); the link
# target lives inside the v2 base image.
RUN if test -n "${JAVA_LINK}"; then ln -s "${JAVA_LINK}" /opt/java; fi

# get the product bits FIRST
COPY --from=product-staging ["/opt/","/opt/"]

# get Ping-wide common scripts
#   this needs to happen after the bits have been laid down
#   so they can be patched
COPY ["pingcommon/opt/","/opt/"]

# apply product-specific hooks and patches
COPY ["ldap-sdk-tools/opt","/opt"]

# add legal information in licenses directory
COPY --from=product-staging ["/opt/LICENSE.txt","/licenses/LDAPSDK-LICENSE-short.txt"]
COPY --from=product-staging ["/opt/LICENSE-UnboundID-LDAPSDK.txt","/licenses/"]
COPY --from=product-staging ["/opt/LICENSE-GPLv2.txt","/licenses/"]
COPY --from=product-staging ["/opt/LICENSE-LGPLv2.1.txt","/licenses/"]

# Run build
RUN ["/opt/build.sh"]

#################################################################################

# The final image (v2 base — PDI-2523 final-stage unification; the v1
# pingbase env-carrier stage is retired, so the env vars it used to supply
# to the hook framework are re-declared below).
FROM ${V2_BASE_IMAGE}

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
#-- The default administrative user for PingData (v1 pingbase carrier
#-- default). Declared in its own ENV statement before the block below so
#-- ROOT_USER_DN expands at build time — Docker does not expand ENV values
#-- against vars declared later or in the same statement.
ENV ROOT_USER="administrator"
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
#-- Whether to clean the staging dir when the container starts
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
#-- License directory
    LICENSE_DIR="${SERVER_ROOT_DIR}" \
#-- The command-line options to provide to the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="" \
#-- The command-line options to provide to the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
    STARTUP_BACKGROUND_OPTS="" \

    PING_IDENTITY_DEVOPS_KEY_REDACT=true \

#-- Legal requirement to explicitly accept the terms of the PingIdentity License
#-- Must be set to 'YES' for the container to start
    PING_IDENTITY_ACCEPT_EULA=NO \
#-- File name for devops-creds passed as a Docker secret
    PING_IDENTITY_DEVOPS_FILE=devops-secret \

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

#-- Heap size (for java products)
    MAX_HEAP_SIZE=384m \

    JVM_TUNING="AGGRESSIVE" \

#-- Triggers verbose messages in scripts using the set -x option.
    VERBOSE=false \

#-- Set the server in debug mode, with increased output
    PING_DEBUG=false \

#-- The name of Ping product, i.e. PingFederate, PingDirectory - must be a valid Ping product type.
#-- This variable should be overridden by child images.
    PING_PRODUCT="" \
#-- Validation toggle for PING_PRODUCT: true to require a valid Ping product
#-- type (e.g. PingFederate,PingDirectory), false to disable the check
    PING_PRODUCT_VALIDATION=true \

#-- Port over which to communicate for LDAP
    LDAP_PORT=1389 \
#-- Port over which to communicate for LDAPS
    LDAPS_PORT=1636 \
#-- Port over which to communicate for HTTPS
    HTTPS_PORT=1443 \
#-- Port for monitoring over JMX protocol
    JMX_PORT=1689 \

#-- The type of orchestration tool used to run the container, normally
#-- set in the deployment (.yaml) file.  Expected values include:
#-- - compose
#-- - swarm
#-- - kubernetes
#-- Defaults to blank (i.e. No type is set)
    ORCHESTRATION_TYPE="" \

#-- Base DN for user data
    USER_BASE_DN=dc=example,dc=com \
#-- Variable with a literal value of '$', to avoid unwanted variable substitution
    DOLLAR='$' \
#-- DN of the server root user
    ROOT_USER_DN="cn=${ROOT_USER}" \
    ENV="${BASE}/.profile" \

#-- Default shell prompt (i.e. productName:hostname:workingDir)
    PS1="\${PING_PRODUCT}:\h:\w\n> " \

#-- PATH used by the container (includes the LDAP SDK tools directory)
    PATH="/opt/tools:${JAVA_HOME}/bin:${BASE}:${SERVER_ROOT_DIR}/bin:${PATH}"

# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
ARG DATE
ARG VERSION

ENV IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
    DATE=${DATE} \
    PING_PRODUCT_VERSION=${VERSION} \
#-- Ping product name
    PING_PRODUCT="ldap-sdk-tools"

# WORKDIR parity with the v1 env-carrier (WORKDIR /opt): the v2 base sets /
# (PDI-2523 unification). ENTRYPOINT below is absolute either way, but
# exec/interactive sessions kept the /opt default (PF precedent).
WORKDIR ${BASE}

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL name="${PING_PRODUCT}" \
      version="${IMAGE_VERSION}" \
      release="${IMAGE_GIT_REV}" \
      date="${DATE}" \
      summary="ldap-sdk-tools provides LDAP Client SDK tools to be used against other PingDirectory instances." \
      description="ldap-sdk-tools provides LDAP Client SDK tools to be used against other PingDirectory instances." \
      license="Apache License v2.0, GPLv2, LGPLv2.1, Ping Identity UnboundID LDAP SDK Free Use"

VOLUME ["/opt/out"]

# Explicit entrypoint chain (PDI-2523 unification): the v1 pingbase
# env-carrier stage used to supply `ENTRYPOINT ["./bootstrap.sh"]`. Absolute
# paths — the v2 base's WORKDIR is /, not /opt. /sbin/tini (0.19.0) ships in
# the v2 base itself.
ENTRYPOINT ["/sbin/tini", "--", "/opt/bootstrap.sh"]
CMD ["start-server"]

# Legal pointer (was shipped by the v1 pingbase carrier as /licenses/license.txt;
# re-homed to the build context for the v2 base, which ships no /licenses).
COPY ["pingbase/license.txt", "/licenses/license.txt"]

COPY --from=final-staging ["/","/"]

#- ## List all available tools
#- `docker run -it --rm pingidentity/ldap-sdk-tools:edge ls`
#-
#- ## Use LDAPSearch
#- ### Get some help
#- `docker run -it --rm pingidentity/ldap-sdk-tools:edge ldapsearch --help`
#-
#- ### Simple search
#- ```Bash
#- docker run -it --rm pingidentity/ldap-sdk-tools:edge \
#-     ldapsearch \
#-         -b dc=example,dc=com \
#-         -p 1389 "(objectClass=*)"
#- ```
#-
#- ### Save output to host file
#- ```Bash
#- docker run -it --rm \
#-     -v /tmp:/opt/out \
#-     pingidentity/ldap-sdk-tools:edge \
#-     ldapsearch \
#-         --baseDN dc=example,dc=com \
#-         --port 1389 \
#-         --outputFormat json "(objectClass=*)" >/tmp/search-result.json
#- ```
#-
#- ## Use manage-certificates
#- ### trusting certificates
#- ```Bash
#- PWD=2FederateM0re
#- mkdir -p /tmp/hibp
#- docker run -it --rm \
#-   -v /tmp/hibp:/opt/out \
#-   pingidentity/ldap-sdk-tools:edge \
#-   manage-certificates trust-server-certificate \
#-     --hostname haveibeenpwned.com \
#-     --port 1443 \
#-     --keystore /opt/out/hibp-2019.jks \
#-     --keystore-password ${PWD}
#- ls -all /tmp/hibp
#- keytool -list \
#-   -keystore /tmp/hibp/hibp-2019.jks \
#-   -storepass ${PWD}
#- ```
