#- # Ping Identity DevOps Docker Image - `pingintelligence-ase`
#-
#- This docker image includes the Ping Identity PingIntelligence API Security Enforcer product binaries
#- and associated hook scripts to create and run PingIntelligence ASE instances.
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
ARG VERBOSE
ARG VERSION

# Get local filesystem product bits if present
COPY ["tmp/", "/tmp/"]

# Download the product bits
COPY --from=common ["/opt/get-product-bits.sh","/opt/get-product-bits.sh"]
RUN /opt/get-product-bits.sh --product ${PRODUCT} --version ${VERSION} \
    && tar -xzvf /tmp/product.zip -C /tmp/ \
        --exclude 'pingidentity/ase/config/api/*.example' \
        --exclude 'pingidentity/ase/config/*.conf' \
        --exclude 'pingidentity/ase/bin/*_rhel7.sh' \
        --exclude 'pingidentity/ase/bin/start_aws.sh' \
        --exclude 'pingidentity/ase/bin/start.sh' \
    && mv /tmp/pingidentity/ase /opt/server/

#################################################################################

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

#################################################################################

# The final image
FROM ${REGISTRY}/pingbase:${GIT_TAG}-${ARCH}
# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
ARG VERSION
# PingIdentity license version
ARG LICENSE_VERSION

ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
    PING_PRODUCT_VERSION=${VERSION} \

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
    PING_INTELLIGENCE_ASE_TIMEZONE="utc" \
#-- Whether the ASE should poll the ABS service that publishes discovered APIs
    PING_INTELLIGENCE_ASE_ABS_PUBLISH=true \
#-- The interval in minute to poll the API discovery list
    PING_INTELLIGENCE_ASE_ABS_PUBLISH_REQUEST_MINUTES=10 \
#-- Defines running mode for API Security Enforcer (Allowed values are inline or sideband).
    PING_INTELLIGENCE_ASE_MODE="sideband" \
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
    PING_INTELLIGENCE_ASE_ENABLE_ABS="true" \
#-- Toggle ABS attack list retrieval
    PING_INTELLIGENCE_ASE_ENABLE_ABS_ATTACK_LIST_RETRIEVAL="true" \
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
#-- Default deployment type -- Supported values (onprem/cloud)
    PING_INTELLIGENCE_ABS_DEPLOYMENT_TYPE="cloud" \
    PING_INTELLIGENCE_ABS_DEPLOYMENT_TYPE_VALIDATION="true|Must be either cloud or onprem|Use cloud if connecting to PingOne, onprem otherwise" \
#-- Obtain the appropriate JWT token in PinOne under Connections->PingIntelligence
    PING_INTELLIGENCE_GATEWAY_CREDENTIALS="" \
    PING_INTELLIGENCE_GATEWAY_CREDENTIALS_REDACT=true \
#-- The amount of time to wait for ASE to start before exiting
    PING_STARTUP_TIMEOUT=8 \
#-- Files tailed once container has started
#-- Other potentially useful log file to tail for debug purposes are logs/controller.log and logs/balancer.log
    TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/*__access__*.log"

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL image-version="${IMAGE_VERSION}" \
      image-git-rev="${IMAGE_GIT_REV}"

COPY --from=final-staging ["/","/"]

#- ## Running a PingIntelligence container
#- To run a PingIntelligence container:
#-
#- ```shell
#-   docker run \
#-            --name pingintellgence \
#-            --publish 8443:8443 \
#-            --detach \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER=user@pingone.com \
#-            --env PING_IDENTITY_DEVOPS_KEY=<edvops key here> \
#-            --env PING_INTELLIGENCE_GATEWAY_CREDENTIALS=<PingIntelligence App JWT here> \
#--           --shm-size 256m \
#-            --ulimit nofile=65536:65536 \
#-            pingidentity/pingintelligence:edge
#- ```
#-
#- Follow Docker logs with:
#-
#- ```
#- docker logs -f pingintelligence
#- ```
#-
#- If using the command above, use cli.sh with:
#-   * Username: admin
#-   * Password: 2FederateM0re
