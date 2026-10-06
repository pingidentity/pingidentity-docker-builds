#- # Ping Identity DevOps Docker Image - `pingtoolkit`
#-
#- This docker image includes the Ping Identity PingToolkit
#- and associated hook scripts to create a container that can pull in a SERVER_PROFILE
#- run scripts.  The typical use case of this image would be an init container or a pod/container
#- to perform tasks aside a running set of pods/containers.
#-
#- ## Related Docker Images
#- - `pingidentity/pingbase` - Parent Image
#- > This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)
#- - `pingidentity/pingcommon` - Common Ping files (i.e. hook scripts)
#-

#################################################################################

# Top level ARGS used in all FROM commands
ARG ARCH
ARG DEPS
ARG GIT_TAG
ARG LATEST_ALPINE_VERSION
ARG REGISTRY
ARG SHIM
# v2 base adoption: CI passes V2_BASE_IMAGE (+ JAVA_LINK for JVM
# products). Empty V2_BASE_IMAGE falls back to the v1 shim for review builds;
# production CI fail-fasts on unmapped jvm ids before ever reaching here.
ARG V2_BASE_IMAGE
ARG JAVA_LINK

#################################################################################

FROM ${REGISTRY}/pingcommon:${GIT_TAG}-${ARCH} AS common

#################################################################################

FROM ${V2_BASE_IMAGE:-${DEPS}${SHIM}} AS final-staging

# v2 base images end at USER 9031:0; staging RUN steps run as root (v1 built
# from a root shim).
USER 0:0
# Re-declared: top-level ARGs are not inherited into stage RUN scope.
ARG JAVA_LINK
# Preserve the JAVA_HOME=/opt/java contract (pingbase env + PATH); the link
# target lives inside the v2 base image. Empty JAVA_LINK (v1 fallback) leaves
# /opt/java to the common scripts as today.
RUN if test -n "${JAVA_LINK}"; then ln -s "${JAVA_LINK}" /opt/java; fi

# get Ping-wide common scripts
COPY --from=common ["/opt/","/opt/"]

# apply product-specific hooks and patches
COPY ["/opt","/opt"]

# Run build
RUN ["/opt/build.sh"]

#################################################################################

# The final image
FROM ${REGISTRY}/pingbase:${GIT_TAG}-${ARCH}
# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
ARG DATE
ARG VERSION

ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
    DATE=${DATE} \
    PING_PRODUCT_VERSION=${VERSION} \
#-- Ping product name
    PING_PRODUCT="PingToolkit" \
#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="tail" \
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="-f /dev/null"

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL name="${PING_PRODUCT}" \
      version="${IMAGE_VERSION}" \
      release="${IMAGE_GIT_REV}" \
      date="${DATE}" \
      summary="PingToolKit creates a container that can pull in a SERVER_PROFILE run scripts." \
      description="PingToolKit creates a container that can pull in a SERVER_PROFILE run scripts."

COPY --from=final-staging ["/","/"]
