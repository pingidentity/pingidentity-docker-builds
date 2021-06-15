#- # Ping Identity DevOps Docker Image - `pingintelligence-ase`
#-
#- This docker image includes the Ping Identity PingIntelligence API Security Enforcer product binaries
#- and associated hook scripts to create and run PingIntelligence ASE instances.
#-
#- ## Related Docker Images
#- - `pingidentity/pingbase` - Parent Image
#- > This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)
#- - `pingidentity/pingcommon` - Common Ping files (i.e. hook scripts)
#- - `pingidentity/pingdownloader` - Used to download product bits
#-
ARG PRODUCT
ARG SHIM
ARG SHIM_TAG
ARG VERSION
ARG JVM
ARG REGISTRY
ARG DEPS
ARG GIT_TAG
ARG ARCH

FROM ${REGISTRY}/${PRODUCT}:staging-${VERSION}-${GIT_TAG} as product-staging
FROM ${REGISTRY}/pingcommon:${GIT_TAG}-${ARCH} as common

FROM ${DEPS}${SHIM} as final-staging
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

FROM ${REGISTRY}/pingbase:${GIT_TAG}-${ARCH}
# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
# PingIdentity license version
ARG LICENSE_VERSION

ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \

#-- Ping product name
    PING_PRODUCT=PingIntelligence_ASE \
#-- Name of license File
    LICENSE_FILE_NAME=PingIntelligence.lic \
#-- License directory
    LICENSE_DIR="${SERVER_ROOT_DIR}/config" \
#-- Shortname used when retrieving license from License Server
    LICENSE_SHORT_NAME=pingintelligence \
#-- Version used when retrieving license from License Server
    LICENSE_VERSION=${LICENSE_VERSION} \

#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start_ase.sh" \
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="" \
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
    STARTUP_BACKGROUND_OPTS="" \

    ROOT_USER_PASSWORD_FILE="" \
    ADMIN_USER_PASSWORD_FILE="" \
    ENCRYPTION_PASSWORD_FILE="" \

#-- PingIntelligence global variables
#-- PingIntelligence default administrative user (this should probably not be changed)
    PING_INTELLIGENCE_ADMIN_USER="admin" \
#-- PingIntelligence default administrative user credentials (this should be changed)
    PING_INTELLIGENCE_ADMIN_PASSWORD="2FederateM0re" \

# ase.conf
#-- The ASE HTTP listener port
    PING_INTELLIGENCE_ASE_HTTP_PORT=8000 \
#-- The ASE HTTPS listener port
    PING_INTELLIGENCE_ASE_HTTPS_PORT=8443 \
#-- the ASE management port
    PING_INTELLIGENCE_ASE_MGMT_PORT=8010 \
#-- The timezone the ASE container is operating in
    PING_INTELLIGENCE_ASE_TIMEZONE="local" \
#-- Defines running mode for API Security Enforcer (Allowed values are inline or sideband).
    PING_INTELLIGENCE_ASE_MODE="inline" \
#-- Enable client-side authentication with tokens in sideband mode
    PING_INTELLIGENCE_ASE_ENABLE_SIDEBAND_AUTHENTICATION="false" \
# Enable hostname rewrite in inline mode
    PING_INTELLIGENCE_ASE_HOSTNAME_REWRITE="false" \
# Keystore password
    PING_INTELLIGENCE_ASE_KEYSTORE_PASSWORD="OBF:AES:sRNp0W7sSi1zrReXeHodKQ:lXcvbBhKZgDTrjQOfOkzR2mpca4bTUcwPAuerMPwvM4" \
#-- For controller.log and balancer.log only 1-5 (FATAL, ERROR, WARNING, INFO, DEBUG)
    PING_INTELLIGENCE_ASE_ADMIN_LOG_LEVEL=4 \
#-- enable cluster
    PING_INTELLIGENCE_ASE_ENABLE_CLUSTER="false" \
#-- Syslog server
    PING_INTELLIGENCE_ASE_SYSLOG_SERVER="" \
#-- Path the to CA certificate
    PING_INTELLIGENCE_ASE_CA_CERT_PATH="" \
#-- enable the ASE health check service
    PING_INTELLIGENCE_ASE_ENABLE_HEALTH="false" \
#-- Set this value to true, to allow API Security Enforcer to send logs to ABS.
    PING_INTELLIGENCE_ASE_ENABLE_ABS="false" \
#-- Toggle ABS attack list retrieval
    PING_INTELLIGENCE_ASE_ENABLE_ABS_ATTACK_LIST_RETRIEVAL="false" \
#-- Toggle whether ASE blocks auto-detected attacks
    PING_INTELLIGENCE_ASE_BLOCK_AUTODETECTED_ATTACKS="false" \
#-- ABS attack list retieval frequency in minutes
    PING_INTELLIGENCE_ASE_ATTACK_LIST_REFRESH_MINUTES=10 \
#-- Hostname refresh interval in seconds
    PING_INTELLIGENCE_ASE_HOSTNAME_REFRESH_SECONDS=60 \
#-- Alert interval for teh decoy services
    PING_INTELLIGENCE_ASE_DECOY_ALERT_INTERVAL_MINUTES=180 \
#-- Toggle X-Forwarded-For
    PING_INTELLIGENCE_ASE_ENABLE_XFORWARDED_FOR="false" \
#-- Toggle ASE Firewall
    PING_INTELLIGENCE_ASE_ENABLE_FIREWALL="true" \
#-- Enable connection keepalive for requests from gateway to ASE in sideband mode
#-- When enabled, ASE sends 'Connection: keep-alive' header in response
#-- When disabled, ASE sends 'Connection: close' header in response
    PING_INTELLIGENCE_ASE_ENABLE_SIDEBAND_KEEPALIVE="false" \
#-- Enable Google Pub/Sub
    PING_INTELLIGENCE_ASE_ENABLE_GOOGLE_PUBSUB="false" \
#-- Toggle the access log
    PING_INTELLIGENCE_ASE_ENABLE_ACCESS_LOG="true" \
#-- Toggle audit logging
    PING_INTELLIGENCE_ASE_ENABLE_AUDIT="false" \
#-- Toggle whether logs are flushed to disk immediately
    PING_INTELLIGENCE_ASE_FLUSH_LOG_IMMEDIATELY="true" \
#-- The number of processes for HTTP requests
    PING_INTELLIGENCE_ASE_HTTP_PROCESS=1 \
#-- The number of processes for HTTPS requests
    PING_INTELLIGENCE_ASE_HTTPS_PROCESS=1 \
#-- Toggle SSLv3 -- this should absolutely stay disabled
    PING_INTELLIGENCE_ASE_ENABLE_SSL_V3="false" \
#-- Google Pub/Sub topic
    PING_INTELLIGENCE_ASE_GOOGLE_PUBSUB_TOPIC="/topic/apimetrics" \
#-- Number of concurrent connections to Google Pub/Sub (Min:1, Max:1024, default: 1000)
    PING_INTELLIGENCE_ASE_GOOGLE_PUBSUB_CONCURRENCY=1000 \
#-- Throttle the number of messages published per second. (Min: 1, Max:10000, default:1000)
    PING_INTELLIGENCE_ASE_GOOGLE_PUBSUB_QPS=1000 \
#-- The API key to use to authenticate with Google
    PING_INTELLIGENCE_ASE_GOOGLE_PUBSUB_APIKEY="" \
#-- Maximum number of messages buffered in memory (Min: 1, Max: 10000, Default: 300)
    PING_INTELLIGENCE_ASE_CACHE_QUEUE_SIZE=300 \
#-- Timeout in seconds to publish a message to Google Pub/Sub. (Min: 10, Max: 300, Default: 30)
    PING_INTELLIGENCE_ASE_GOOGLE_PUBSUB_TIMEOUT_SECONDS=30 \
#-- Kernel TCP send buffer size in bytes
    PING_INTELLIGENCE_TCP_SEND_BUFFER_BYTES=212992 \
#--Kenrel TCP receive buffer size in bytes
    PING_INTELLIGENCE_TCP_RECEIVE_BUFFER_BYTES=212992 \
#--
    PING_INTELLIGENCE_ASE_ATTACK_LIST_MEMORY="128MB" \

# cluster.conf
#-- a comma-separated list of hostname:cluster_manager_port or IPv4_address:cluster_manager_port
#-- the ASE will try to connect to each server peer in the list
    PING_INTELLIGENCE_CLUSTER_PEER_NODE_CSV_LIST="" \
#-- The ASE cluster ID -- this must be unique
    PING_INTELLIGENCE_CLUSTER_ID="ase_cluster" \
#-- The ASE cluster management port
    PING_INTELLIGENCE_CLUSTER_MGMT_PORT=8020 \
#-- Secret key required to join the cluster
    PING_INTELLIGENCE_CLUSTER_SECRET_KEY="OBF:AES:nPJOh3wXQWK/BOHrtKu3G2SGiAEElOSvOFYEiWfIVSdummoFwSR8rDh2bBnhTDdJ:7LFcqXQlqkW9kldQoFg0nJoLSojnzHDbD3iAy84pT84" \

# abs.conf
#-- a comma-separated list of abs nodes having hostname:port or ipv4:port as an address.
    PING_INTELLIGENCE_ABS_ENDPOINT="" \
#-- access key for ase to authenticate with abs node
    PING_INTELLIGENCE_ABS_ACCESS_KEY="" \
#-- secret key for ase to authenticate with abs node
    PING_INTELLIGENCE_ABS_SECRET_KEY="" \
#-- Setting this value to true will enable encrypted communication with ABS.
    PING_INTELLIGENCE_ABS_ENABLE_SSL="true" \
#-- Configure the location of ABS's trusted CA certificates.
    PING_INTELLIGENCE_ABS_CA_CERT_PATH="" \


#-- Files tailed once container has started
    TAIL_LOG_FILES=""

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL image-version="${IMAGE_VERSION}" \
      image-git-rev="${IMAGE_GIT_REV}"

COPY --from=final-staging ["/","/"]
