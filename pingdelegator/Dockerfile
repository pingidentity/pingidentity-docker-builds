#- # Ping Identity Docker Image - `pingdelegator`
#- 
#- This docker image provides a tomcat image with the PingDataConsole
#- deployed to be used in configuration of the PingData products.
#-
#- ## Related Docker Images
#- - `pingidentity/pingdownloader` - Image used to download ping product
#- - `tomcat:8-jre8-alpine` - Tomcat engine to serve PingDataConsole .war file
#-

ARG PRODUCT
ARG SHIM
ARG SHIM_TAG
ARG VERSION
ARG REGISTRY
ARG GIT_TAG

FROM ${REGISTRY}/${PRODUCT}:staging-${VERSION}-${GIT_TAG} as product-staging
FROM ${REGISTRY}/pingcommon:${GIT_TAG} as common

FROM ${SHIM} as final-staging
ENV SHIM=${SHIM}

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

#
# the final image 
#
FROM ${REGISTRY}/pingbase:${GIT_TAG}
COPY --from=final-staging ["/","/"]

ENV DELEGATOR_PUBLIC_HOSTNAME=pingdelegator
ENV DELEGATOR_HTTP_PORT=8080
ENV DELEGATOR_HTTPS_PORT=8443

ENV STARTUP_COMMAND="nginx"
ENV STARTUP_FOREGROUND_OPTS="-c ${SERVER_ROOT_DIR}/etc/nginx.conf"
# ENV STARTUP_FOREGROUND_OPTS="run"
# ENV STARTUP_BACKGROUND_OPTS="start"

#- ## Run
#- To run a PingDataConsole container: 
#- 
#- ```shell
#-   docker run \
#-            --name pingdelegator \
#-            --publish ${HTTPS_PORT}:${HTTPS_PORT} \
#-            --detach \
#-            pingidentity/pingdelegator
#- ```
#- 
#- 
#- Follow Docker logs with:
#- 
#- ```
#- docker logs -f pingdelegator
#- ```
#- 
#- If using the command above with the embedded [server profile](../server-profiles/README.md), log in with: 
#- * http://localhost:${HTTPS_PORT}/console/login
#- ```
#- Server: pingdirectory
#- Username: administrator
#- Password: 2FederateM0re
#- ```
#- >make sure you have a PingDirectory running
