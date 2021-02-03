#- # Ping Identity DevOps Docker Image - `pingintelligence-ase`
#-
#- This docker image includes the Ping Identity PingIntelligence API Security Enforcer product binaries
#- and associated hook scripts to create and run PingIntelligence ASE instances.
#-
#- ## Related Docker Images
#- - `pingidentity/pingbase` - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)**
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

FROM ${REGISTRY}/${PRODUCT}:staging-${VERSION}-${GIT_TAG} as product-staging
FROM ${REGISTRY}/pingcommon:${GIT_TAG} as common

FROM ${DEPS}${SHIM} as final-staging
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

#-- PingIntelligence global variables
#-- PingIntelligence default administrative user (this should probably not be changed)
ENV PING_INTELLIGENCE_ADMIN_USER="admin"
#-- PingIntelligence default administrative user credentials (this should be changed)
ENV PING_INTELLIGENCE_ADMIN_PASSWORD="2FederateM0re"

# ase.conf
#-- The ASE HTTP listener port
ENV PING_INTELLIGENCE_ASE_HTTP_PORT=8000
#-- The ASE HTTPS listener port
ENV PING_INTELLIGENCE_ASE_HTTPS_PORT=8443
#-- the ASE management port
ENV PING_INTELLIGENCE_ASE_MGMT_PORT=8010
#-- The timezone the ASE container is operating in
ENV PING_INTELLIGENCE_ASE_TIMEZONE="local"
#-- Defines running mode for API Security Enforcer (Allowed values are inline or sideband).
ENV PING_INTELLIGENCE_ASE_MODE="inline"
#-- Enable client-side authentication with tokens in sideband mode
ENV PING_INTELLIGENCE_ASE_ENABLE_SIDEBAND_AUTHENTICATION="false"
# Enable hostname rewrite in inline mode
ENV PING_INTELLIGENCE_ASE_HOSTNAME_REWRITE="false"
# Keystore password
ENV PING_INTELLIGENCE_ASE_KEYSTORE_PASSWORD="OBF:AES:sRNp0W7sSi1zrReXeHodKQ:lXcvbBhKZgDTrjQOfOkzR2mpca4bTUcwPAuerMPwvM4"
#-- For controller.log and balancer.log only 1-5 (FATAL, ERROR, WARNING, INFO, DEBUG)
ENV PING_INTELLIGENCE_ASE_ADMIN_LOG_LEVEL=4
#-- enable cluster
ENV PING_INTELLIGENCE_ASE_ENABLE_CLUSTER="false"
#-- Syslog server
ENV PING_INTELLIGENCE_ASE_SYSLOG_SERVER=""
#-- Path the to CA certificate
ENV PING_INTELLIGENCE_ASE_CA_CERT_PATH=""
#-- enable the ASE health check service
ENV PING_INTELLIGENCE_ASE_ENABLE_HEALTH="false"
#-- Set this value to true, to allow API Security Enforcer to send logs to ABS.
ENV PING_INTELLIGENCE_ASE_ENABLE_ABS="false"
#-- Toggle ABS attack list retrieval
ENV PING_INTELLIGENCE_ASE_ENABLE_ABS_ATTACK_LIST_RETRIEVAL="false"
#-- Toggle whether ASE blocks auto-detected attacks
ENV PING_INTELLIGENCE_ASE_BLOCK_AUTODETECTED_ATTACKS="false"
#-- ABS attack list retieval frequency in minutes
ENV PING_INTELLIGENCE_ASE_ATTACK_LIST_REFRESH_MINUTES=10
#-- Hostname refresh interval in seconds
ENV PING_INTELLIGENCE_ASE_HOSTNAME_REFRESH_SECONDS=60
#-- Alert interval for teh decoy services
ENV PING_INTELLIGENCE_ASE_DECOY_ALERT_INTERVAL_MINUTES=180
#-- Toggle X-Forwarded-For
ENV PING_INTELLIGENCE_ASE_ENABLE_XFOWARDED_FOR="false"
#-- Toggle ASE Firewall
ENV PING_INTELLIGENCE_ASE_ENABLE_FIREWALL="true"
#-- Enable connection keepalive for requests from gateway to ASE in sideband mode
#-- When enabled, ASE sends 'Connection: keep-alive' header in response
#-- When disabled, ASE sends 'Connection: close' header in response
ENV PING_INTELLIGENCE_ASE_ENABLE_SIDEBAND_KEEPALIVE="false"
#-- Enable Google Pub/Sub
ENV PING_INTELLIGENCE_ASE_ENABLE_GOOGLE_PUBSUB="false"
#-- Toggle the access log
ENV PING_INTELLIGENCE_ASE_ENABLE_ACCESS_LOG="true"
#-- Toggle audit logging
ENV PING_INTELLIGENCE_ASE_ENABLE_AUDIT="false"
#-- Toggle whether logs are flushed to disk immediately
ENV PING_INTELLIGENCE_ASE_FLUSH_LOG_IMMEDIATELY="true"
#-- The number of processes for HTTP requests
ENV PING_INTELLIGENCE_ASE_HTTP_PROCESS=1
#-- The number of processes for HTTPS requests
ENV PING_INTELLIGENCE_ASE_HTTPS_PROCESS=1
#-- Toggle SSLv3 -- this should absolutely stay disabled
ENV PING_INTELLIGENCE_ASE_ENABLE_SSL_V3="false"
#-- Google Pub/Sub topic
ENV PING_INTELLIGENCE_ASE_GOOGLE_PUBSUB_TOPIC="/topic/apimetrics"
#-- Number of concurrent connections to Google Pub/Sub (Min:1, Max:1024, default: 1000)
ENV PING_INTELLIGENCE_ASE_GOOGLE_PUBSUB_CONCURRENCY=1000
#-- Throttle the number of messages published per second. (Min: 1, Max:10000, default:1000)
ENV PING_INTELLIGENCE_ASE_GOOGLE_PUBSUB_QPS=1000
#-- The API key to use to authenticate with Google
ENV PING_INTELLIGENCE_ASE_GOOGLE_PUBSUB_APIKEY=""
#-- Maximum number of messages buffered in memory (Min: 1, Max: 10000, Default: 300)
ENV PING_INTELLIGENCE_ASE_CACHE_QUEUE_SIZE=300
#-- Timeout in seconds to publish a message to Google Pub/Sub. (Min: 10, Max: 300, Default: 30)
ENV PING_INTELLIGENCE_ASE_GOOGLE_PUBSUB_TIMEOUT_SECONDS=30
#-- Kernel TCP send buffer size in bytes
ENV PING_INTELLIGENCE_TCP_SEND_BUFFER_BYTES=212992
#--Kenrel TCP receive buffer size in bytes
ENV PING_INTELLIGENCE_TCP_RECEIVE_BUFFER_BYTES=212992
#--
ENV PING_INTELLIGENCE_ASE_ATTACK_LIST_MEMORY="128MB"

# cluster.conf
#-- a comma-separated list of hostname:cluster_manager_port or IPv4_address:cluster_manager_port
#-- the ASE will try to connect to each server peer in the list
ENV PING_INTELLIGENCE_CLUSTER_PEER_NODE_CSV_LIST=""
#-- The ASE cluster ID -- this must be unique
ENV PING_INTELLIGENCE_CLUSTER_ID="ase_cluster"
#-- The ASE cluster management port
ENV PING_INTELLIGENCE_CLUSTER_MGMT_PORT=8020
#-- Secret key required to join the cluster
ENV PING_INTELLIGENCE_CLUSTER_SECRET_KEY="OBF:AES:nPJOh3wXQWK/BOHrtKu3G2SGiAEElOSvOFYEiWfIVSdummoFwSR8rDh2bBnhTDdJ:7LFcqXQlqkW9kldQoFg0nJoLSojnzHDbD3iAy84pT84"

# abs.conf
#-- a comma-separated list of abs nodes having hostname:port or ipv4:port as an address.
ENV PING_INTELLIGENCE_ABS_ENDPOINT=""
#-- access key for ase to authenticate with abs node
ENV PING_INTELLIGENCE_ABS_ACCESS_KEY=""
#-- secret key for ase to authenticate with abs node
ENV PING_INTELLIGENCE_ABS_SECRET_KEY=""
#-- Setting this value to true will enable encrypted communication with ABS.
ENV PING_INTELLIGENCE_ABS_ENABLE_SSL="true"
#-- Configure the location of ABS's trusted CA certificates.
ENV PING_INTELLIGENCE_ABS_CA_CERT_PATH=""


#-- Files tailed once container has started
ENV TAIL_LOG_FILES=""

COPY --from=final-staging ["/","/"]
