#- # Ping Identity Docker Image - `pingcommon`
#-
#- This docker image provides a busybox image to house the base hook scripts
#- and default entrypoint.sh used throughout the Ping Identity DevOps product images.
#-
#-

#################################################################################

# Top level ARGS used in all FROM commands
ARG DEPS
ARG LATEST_ALPINE_VERSION

#################################################################################

# Always use alpine to download product bits
FROM ${DEPS}alpine:${LATEST_ALPINE_VERSION} as product-staging

# ARGS used in get-product-bits.sh RUN command
ARG ARTIFACTORY_URL
ARG PRODUCT=tini
ARG VERBOSE
ARG VERSION=0.19.0

# Get gnupg for get-product-bits.sh
RUN apk --no-cache --update add gnupg

# Get public signing keys for Tini
COPY ["key.gpg", "/tmp"]

# Download the product bits
COPY ["/opt/get-product-bits.sh","/opt/get-product-bits.sh"]
RUN /opt/get-product-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && mv "/tmp/product.zip" "/opt/tini" \
    && chmod +x "/opt/tini"

#################################################################################

# The final image
FROM scratch
COPY --from=product-staging ["/opt","/opt"]
COPY ["opt/","/opt/"]
