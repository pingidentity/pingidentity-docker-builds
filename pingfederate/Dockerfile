#- # Ping Identity DevOps Docker Image - `pingfederate`
#-
#- This docker image includes the Ping Identity PingFederate product binaries
#- and associated hook scripts to create and run both PingFederate Admin and
#- Engine nodes.
#-
#- ## Related Docker Images
#- - pingidentity/pingbase - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)**
#- - pingidentity/pingcommon - Common Ping files (i.e. hook scripts)
#- - pingidentity/pingdownloader - Used to download product bits
#-

#
# Staging product to a seperate image saves us the download + staging
# for each shim a product version is built for
#
ARG PRODUCT
ARG SHIM
ARG SHIM_TAG
ARG VERSION
ARG JVM
ARG REGISTRY
ARG DEPS
ARG GIT_TAG

FROM ${REGISTRY}/${PRODUCT}:staging-${VERSION}-${GIT_TAG} as product-staging
FROM ${REGISTRY}/pingcommon:${GIT_TAG} as common
FROM ${REGISTRY}/pingjvm:${JVM}_${SHIM_TAG}-${GIT_TAG} as jvm

FROM ${DEPS}${SHIM} as final-staging
ENV SHIM=${SHIM}

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


#
# The final image
#
FROM ${REGISTRY}/pingbase:${GIT_TAG}
ARG LICENSE_VERSION
ENV PING_PRODUCT="PingFederate"
ENV LICENSE_DIR="${SERVER_ROOT_DIR}/server/default/conf"
ENV LICENSE_FILE_NAME="pingfederate.lic"
ENV LICENSE_SHORT_NAME="PF"
ENV LICENSE_VERSION=${LICENSE_VERSION}
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh"
ENV TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/server.log

#-- Defines the port on which the PingFederate administrative
#-- console and API runs.
ENV PF_ADMIN_PORT=9999

#-- Defines the port on which PingFederate listens for
#-- encrypted HTTPS (SSL/TLS) traffic.
ENV PF_ENGINE_PORT=9031

#-- Flag to turn on PingFederate Engine debugging
#-- Used in run.sh
ENV PF_ENGINE_DEBUG=false

#-- Flag to turn on PingFederate Admin debugging
#-- Used in run.sh
ENV PF_ADMIN_DEBUG=false

#-- Defines the port on which PingFederate opens up a java debugging port.
#-- Used in run.sh
ENV PF_DEBUG_PORT=9030

#-- Operational Mode
#-- Indicates the operational mode of the runtime server in run.properties
#-- Options include STANDALONE, CLUSTERED_CONSOLE, CLUSTERED_ENGINE.
ENV OPERATIONAL_MODE="STANDALONE"

#-- Defines mechamism for console authentication in run.properties.
#-- Options include none, native, LDAP, cert, RADIUS, OIDC.
#-- If not set, default is native.
ENV PF_CONSOLE_AUTHENTICATION=

#-- Defines mechamism for admin api authentication in run.properties.
#-- Options include none, native, LDAP, cert, RADIUS, OIDC.
#-- If not set, default is native.
ENV PF_ADMIN_API_AUTHENTICATION=

#-- Hardware Security Module Mode in run.properties
#-- Options include OFF, AWSCLOUDHSM, NCIPHER, LUNA, BCFIPS.
ENV HSM_MODE="OFF"

#-- This is the username for an account within the LDAP Directory Server
#-- that can be used to perform user lookups for authentication and other
#-- user level search operations.  Set if PF_CONSOLE_AUTHENTICATION or
#-- PF_ADMIN_API_AUTHENTICATION=LDAP
ENV PF_LDAP_USERNAME="cn=pingfederate"

#-- This is the password for the Username specified above.
#-- This property should be obfuscated using the 'obfuscate.sh' utility.
#-- Set if PF_CONSOLE_AUTHENTICATION or PF_ADMIN_API_AUTHENTICATION=LDAP
ENV PF_LDAP_PASSWORD="OBF:JWE:eyJhbGciOiJkaXIiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2Iiwia2lkIjoiRW1JY1UxOVdueSIsInZlcnNpb24iOiI5LjIuMS4xIn0..euBO0bawJz3XC_plAjxECg.yF7BpnCTPZlpZUo21WQ5IQ.YlLtlJTxXhrp3LsxyQDo5g"

#-- IP address for cluster communication.  Set to NON_LOOPBACK to
#-- allow the system to choose an available non-loopback IP address.
ENV CLUSTER_BIND_ADDRESS="NON_LOOPBACK"

ENV BULK_CONFIG_DIR="${OUT_DIR}/instance/bulk-config"
ENV BULK_CONFIG_FILE=data.json

EXPOSE 9031 9999

# get the staged bits
COPY --from=final-staging ["/","/"]

#- ## Running a PingFederate container
#- To run a PingFederate container:
#-
#- ```shell
#-   docker run \
#-            --name pingfederate \
#-            --publish 9999:9999 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingfederate \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingfederate:edge
#- ```
#-
#- Follow Docker logs with:
#-
#- ```
#- docker logs -f pingfederate
#- ```
#-
#- If using the command above with the embedded [server profile](https://devops.pingidentity.com/reference/config/), log in with:
#- * https://localhost:9999/pingfederate/app
#-   * Username: Administrator
#-   * Password: 2FederateM0re
