#- # Ping Identity Docker Image - `pingdataconsole`
#-
#- This docker image provides a tomcat image with the PingDataConsole
#- deployed to be used in configuration of the PingData products.
#-
#- ## Related Docker Images
#- - `tomcat:9-jre8` - Tomcat engine to serve PingDataConsole .war file
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
FROM ${REGISTRY}/pingjvm:${JVM}-${SHIM_TAG}-${GIT_TAG}-${ARCH} as jvm

#################################################################################

# Always use alpine to download product bits
FROM ${DEPS}alpine:${LATEST_ALPINE_VERSION} as product-staging

# ARGS used in get-product-bits.sh RUN command
ARG ARTIFACTORY_URL
ARG DEPENDENCY_0_PRODUCT
ARG DEPENDENCY_0_VERSION
ARG PRODUCT
ARG SNAPSHOT_URL
ARG VERBOSE
ARG VERSION

# Get gnupg and libxml2-utils for get-product-bits.sh
RUN apk --no-cache --update add gnupg libxml2-utils

# Get public signing keys for Apache Tomcat
COPY ["keys.gpg", "/tmp"]

# Get local filesystem product bits if present
COPY ["tmp/", "/tmp/"]

# Download the product bits
COPY --from=common ["/opt/get-product-bits.sh","/opt/get-product-bits.sh"]
RUN /opt/get-product-bits.sh --product ${DEPENDENCY_0_PRODUCT} --version ${DEPENDENCY_0_VERSION} --output "appserver.zip" \
    && unzip -q /tmp/appserver.zip \
        -d /tmp \
        -x *.bat \
        -x *.dll \
        -x *.exe \
        -x */temp/* \
        -x */webapps/docs/* \
        -x */webapps/examples/* \
        -x */webapps/*manager/* \
        -x */bin/commons-daemon* \
        -x */bin/tomcat-native.tar.gz \
        -x */webapps/ROOT/*.svg \
        -x */webapps/ROOT/*.png \
        -x */webapps/ROOT/*.gif \
        -x */webapps/ROOT/*.css \
        -x */webapps/ROOT/*.jsp \
        -x */webapps/ROOT/*.ico \
        -x */webapps/ROOT/*.txt \
        -x */conf/server.xml \
        -x */conf/tomcat-users.xml \
    && mv /tmp/${DEPENDENCY_0_PRODUCT}-${DEPENDENCY_0_VERSION} /opt/server \
    && rm -f /tmp/appserver.zip
RUN /opt/get-product-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && unzip -q -d /tmp/ /tmp/product.zip PingDirectory/resource/admin-console.zip \
    && unzip -q -d /tmp/ /tmp/PingDirectory/resource/admin-console.zip admin-console.war \
    && mkdir /opt/server/webapps/console \
    && unzip -q /tmp/admin-console.war \
        -d /opt/server/webapps/console \
        -x *-sources.jar \
        -x *unboundid-ldapsdk-*.jar

#################################################################################

FROM ${DEPS}${SHIM} as final-staging

# get the product bits FIRST
COPY --from=product-staging ["/opt/","/opt/"]

# get Ping-wide common scripts
#   this needs to happen after the bits have been laid down
#   so they can be patched
COPY --from=common ["/opt/","/opt/"]

# get the jvm
COPY --from=jvm ["/opt/java","/opt/java"]

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
ARG VERSION

ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
    PING_PRODUCT_VERSION=${VERSION} \
#-- PingDataConsole HTTP listen port
    HTTP_PORT=8080 \
#-- PingDataConsole HTTPS listen port
    HTTPS_PORT=8443 \
#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/catalina.sh" \
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="run" \
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
    STARTUP_BACKGROUND_OPTS="start" \
#-- Files tailed once container has started
    TAIL_LOG_FILES=${SERVER_ROOT_DIR}/logs/console.log

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL image-version="${IMAGE_VERSION}" \
      image-git-rev="${IMAGE_GIT_REV}"

COPY --from=final-staging ["/","/"]

#- ## Run
#- To run a PingDataConsole container:
#-
#- ```shell
#-   docker run \
#-            --name pingdataconsole \
#-            --publish ${HTTPS_PORT}:${HTTPS_PORT} \
#-            --detach \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingdataconsole:edge
#- ```
#-
#-
#- Follow Docker logs with:
#-
#- ```
#- docker logs -f pingdataconsole
#- ```
#-
#- If using the command above with the embedded [server profile](https://devops.pingidentity.com/reference/config/), log in with:
#- * http://localhost:${HTTPS_PORT}/console/login
#- ```
#- Server: pingdirectory:1636
#- Username: administrator
#- Password: 2FederateM0re
#- ```
#- > make sure you have a PingDirectory running
