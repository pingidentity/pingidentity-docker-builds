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

# Always use alpine to download product bits
FROM ${DEPS}alpine:${LATEST_ALPINE_VERSION} AS product-staging

# ARGS used in get-product-bits.sh RUN command
ARG PRODUCT
ARG VERSION
ARG ARTIFACTORY_URL
ARG VERBOSE

# Get gnupg for get-product-bits.sh
RUN apk --no-cache --update add gnupg

# Get public signing keys for Apache JMeter
COPY ["keys.gpg", "/tmp"]

# Download the product bits
COPY --from=common ["/opt/get-product-bits.sh","/opt/get-product-bits.sh"]
RUN /opt/get-product-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip -q /tmp/product.zip \
        -d /tmp \
        -x *.bat \
        -x *.dll \
        -x *.exe \
        -x *.ini \
        -x */printable_docs/* \
        -x */docs/* \
   && mv /tmp/${PRODUCT}-${VERSION} /opt/server

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

# get the product bits FIRST
COPY --from=product-staging ["/opt/","/opt/"]

# get Ping-wide common scripts
#   this needs to happen after the bits have been laid down
#   so they can be patched
COPY --from=common ["/opt/","/opt/"]

# apply product-specific hooks and patches
COPY ["/opt","/opt"]

# Run build
RUN ["/opt/build.sh"]

#################################################################################

# the final image
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
    PING_PRODUCT="Apache-JMeter" \

#-- Percentage of the container memory to allocate to PingFederate JVM
#-- DO NOT set to 100% or your JVM will exit with OutOfMemory errors and the container will terminate
    JAVA_RAM_PERCENTAGE=90.0 \

#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh"

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL name="${PING_PRODUCT}" \
      version="${IMAGE_VERSION}" \
      release="${IMAGE_GIT_REV}" \
      date="${DATE}" \
      summary="Apache JMeter can send HTTPS requests to any given PingFederate server" \
      description="Apache JMeter can send HTTPS requests to any given PingFederate server"
COPY --from=final-staging ["/","/"]
