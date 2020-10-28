#- # Ping Identity DevOps Docker Image - `pingintelligence-ase`
#-
#- This docker image includes the Ping Identity PingIntelligence API Security Enforcer product binaries
#- and associated hook scripts to create and run PingIntelligence ASE instances.
#-
#- ## Related Docker Images
#- - pingidentity/pingbase - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://pingidentity-devops.gitbook.io/devops/dockerimagesref/pingbase)**
#- - pingidentity/pingdownloader - Used to download product bits
#-
ARG PRODUCT
ARG SHIM
ARG SHIM_TAG
ARG VERSION
ARG JVM
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

FROM ${REGISTRY}/pingbase:${GIT_TAG}
#-- PingIdentity license version
ARG LICENSE_VERSION
#-- Ping product name
ENV PING_PRODUCT=PingIntelligence_ASE
#-- Name of License File
ENV LICENSE_FILE_NAME=PingIntelligence.lic
ENV LICENSE_DIR="${SERVER_ROOT_DIR}/config"
#-- Shortname used when retrieving license from License Server
ENV LICENSE_SHORT_NAME=pingintelligence
#-- Version used when retrieving license from License Server
ENV LICENSE_VERSION=${LICENSE_VERSION}

ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start_ase.sh"
ENV STARTUP_FOREGROUND_OPTS=""
ENV STARTUP_BACKGROUND_OPTS=""

ENV ROOT_USER_PASSWORD_FILE=""
ENV ADMIN_USER_PASSWORD_FILE=""
ENV ENCRYPTION_PASSWORD_FILE=""

# ase.conf
#-- The timezone the ASE container is operating in
ENV ASE_TIMEZONE="local"
#-- Defines running mode for API Security Enforcer (Allowed values are inline or sideband).
ENV MODE="inline"
#-- For controller.log and balancer.log only 1-5 (FATAL, ERROR, WARNING, INFO, DEBUG)
ENV ADMIN_LOG_LEVEL=4
#-- enable cluster
ENV ENABLE_CLUSTER="false"
#-- Set this value to true, to allow API Security Enforcer to send logs to ABS.
ENV ENABLE_ABS="false"
#-- Enable Google Pub/Sub
ENV ENABLE_GOOGLE_PUBSUB="false"
#-- Google Pub/Sub topic
ENV GOOGLE_PUBSUB_TOPIC="/topic/apimetrics"
#-- Number of concurrent connections to Google Pub/Sub (Min:1, Max:1024, default: 1000)
ENV GOOGLE_PUBSUB_CONCURRENCY=1000
#-- Throttle the number of messages published per second. (Min: 1, Max:10000, default:1000)
ENV GOOGLE_PUBSUB_QPS=1000
#-- The API key to use to authenticate with Google
ENV GOOGLE_PUBSUB_APIKEY=""
#-- Maximum number of messages buffered in memory (Min: 1, Max: 10000, Default: 300)
ENV CACHE_QUEUE_SIZE=300
#-- Timeout in seconds to publish a message to Google Pub/Sub. (Min: 10, Max: 300, Default: 30)
ENV GOOGLE_PUBSUB_TIMEOUT=30

# cluster.conf
#-- a comma-separated list of hostname:cluster_manager_port or IPv4_address:cluster_manager_port
ENV PEER_NODE=""

# abs.conf
#-- a comma-separated list of abs nodes having hostname:port or ipv4:port as an address.
ENV ABS_ENDPOINT="127.0.0.1:8080"
#-- access key for ase to authenticate with abs node
ENV ABS_ACCESS_KEY=""
#-- secret key for ase to authenticate with abs node
ENV ABS_SECRET_KEY=""
#-- Setting this value to true will enable encrypted communication with ABS.
ENV ABS_ENABLE_SSL="true"
#-- Configure the location of ABS's trusted CA certificates.
ENV ABS_CA_CERT_PATH=""


#-- Files tailed once container has started
ENV TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/*"

COPY --from=final-staging ["/","/"]
