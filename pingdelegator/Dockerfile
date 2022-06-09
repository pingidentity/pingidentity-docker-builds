#- # Ping Identity Docker Image - `pingdelegator`
#-
#- This docker image provides an NGINX instance with PingDelegator
#- that can be used in administering PingDirectory Users/Groups.
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
ARG JVM
ARG LATEST_ALPINE_VERSION
ARG REGISTRY
ARG SHIM
ARG SHIM_TAG

#################################################################################

FROM ${REGISTRY}/pingcommon:${GIT_TAG}-${ARCH} as common

#################################################################################

# Always use alpine to download product bits
FROM ${DEPS}alpine:${LATEST_ALPINE_VERSION} as product-staging

# ARGS used in get-product-bits.sh RUN command
ARG ARTIFACTORY_URL
ARG PRODUCT
ARG SNAPSHOT_URL
ARG VERBOSE
ARG VERSION

# Get libxml2-utils for get-product-bits.sh
RUN apk --no-cache --update add libxml2-utils

# Get local filesystem product bits if present
COPY ["tmp/", "/tmp/"]

# Download the product bits
COPY --from=common ["/opt/get-product-bits.sh","/opt/get-product-bits.sh"]
RUN /opt/get-product-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip -q /tmp/product.zip -d /tmp \
    && mkdir -p /opt/server/html \
    && mv /tmp/delegator/app /opt/server/html/delegator

#################################################################################

FROM ${DEPS}${SHIM} as final-staging

# get the product bits FIRST
COPY --from=product-staging ["/opt/","/opt/"]
COPY ["nginx.conf", "/etc/nginx/nginx.conf"]

# get Ping-wide common scripts
#   this needs to happen after the bits have been laid down
#   so they can be patched
COPY --from=common ["/opt/","/opt/"]

# apply product-specific hooks and patches
COPY ["/opt","/opt"]

# Run build
RUN ["/opt/build.sh"]

#################################################################################

# The final image
FROM ${REGISTRY}/pingbase:${GIT_TAG}-${ARCH}
COPY --from=final-staging ["/","/"]

# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
ARG VERSION

ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
    PING_PRODUCT_VERSION=${VERSION} \

    PD_DELEGATOR_PUBLIC_HOSTNAME=localhost \
    PD_DELEGATOR_HTTP_PORT=6080 \
    PD_DELEGATOR_HTTPS_PORT=6443 \

#-- The hostname for the public Ping Federate instance used for SSO.
    PF_ENGINE_PUBLIC_HOSTNAME=localhost \

#-- The port for the public Ping Federate instance used for SSO.
#-- NOTE: If using port 443 along with a base URL with no specified port, set to
#-- an empty string.
    PF_ENGINE_PUBLIC_PORT=9031 \

#-- The client id that was set up with Ping Federate for Ping Delegator.
    PF_DELEGATOR_CLIENTID=dadmin \

#-- The hostname for the DS instance the app will be interfacing with.
    PD_ENGINE_PUBLIC_HOSTNAME=localhost \

#-- The HTTPS port for the DS instance the app will be interfacing with.
    PD_ENGINE_PUBLIC_PORT=1443 \

#-- The length of time (in minutes) until the session will require a new login attempt
    PD_DELEGATOR_TIMEOUT_LENGTH_MINS=30 \

#-- The filename used as the logo in the header bar, relative to this application's build directory.
#-- Note about logos: The size of the image will be scaled down to fit 22px of height and a max-width
#-- of 150px. For best results, it is advised to make the image close to this height and width ratio
#-- as well as to crop out any blank spacing around the logo to maximize its presentation.
#-- e.g. '${SERVER_ROOT_DIR}/html/delegator/images/my_company_logo.png'
    PD_DELEGATOR_HEADER_BAR_LOGO= \

#-- The namespace for the Delegated Admin API on the DS instance. In most cases, this does not need
#-- to be set here. e.g. 'dadmin/v2'
    PD_DELEGATOR_DADMIN_API_NAMESPACE= \

#-- Set to true if the "profile" scope is supported for the Delegated Admin OIDC client on
#-- PingFederate and you wish to use it to show the current user's name in the navigation.
    PD_DELEGATOR_PROFILE_SCOPE_ENABLED=false \

#-- The number of NginX worker processes -- Default: auto
    NGINX_WORKER_PROCESSES="auto" \
#-- The number of NginX worker connections -- Default: 1024
    NGINX_WORKER_CONNECTIONS="1024" \
#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="nginx" \
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="-c ${SERVER_ROOT_DIR}/etc/nginx.conf"
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
ENV STARTUP_BACKGROUND_OPTS="${STARTUP_FOREGROUND_OPTS}"

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL image-version="${IMAGE_VERSION}" \
      image-git-rev="${IMAGE_GIT_REV}"

#- ## Run
#- To run a PingDelegator container with HTTPS_PORT=6443 (6443 is simply a convention for
#- PingDelegator so conflicts are reduced with other container HTTPS ports):
#-
#- ```shell
#-   docker run \
#-            --name pingdelegator \
#-            --publish 6443:6443 \
#-            --detach \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingdelegator:edge
#- ```
#-
#- PingDelegator does require running instances of PingFederate/PingDirectory.  To
#- run the an example deployment of PingDelegator in docker-compose, the ping-devops
#- tool can be used:
#-
#- ```shell
#-   ping-devops docker start simplestack
#- ```
