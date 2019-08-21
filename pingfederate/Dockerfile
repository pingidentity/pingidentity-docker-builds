#- # Ping Identity DevOps Docker Image - `pingfederate`
#- 
#- This docker image includes the Ping Identity PingFederate product binaries
#- and associated hook scripts to create and run both PingFederate Admin and
#- Engine nodes. 
#-
#- ## Related Docker Images
#- - pingidentity/pingbase - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://pingidentity-devops.gitbook.io/devops/docker-images/pingbase)**
#- - pingidentity/pingcommon - Common Ping files (i.e. hook scripts)
#- - pingidentity/pingdownloader - Used to download product bits
#-

ARG SHIM=alpine

FROM pingidentity/pingdownloader as staging
ARG PRODUCT=pingfederate
ARG VERSION=9.3.1

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
	&& unzip /tmp/product.zip -d /tmp/ \
	&& find /tmp -type f \( -iname \*.bat -o -iname \*.dll -o -iname \*.exe \) -exec rm -f {} \; \
	&& mv /tmp/pingfederate-*/pingfederate /opt/server
COPY [ "liveness.sh", "/opt/"]
COPY [ "run.sh", "/opt/server/bin/run.sh" ]

#
# The final image 
#
FROM pingidentity/pingbase:${SHIM}
EXPOSE 9031 9999
ENV PING_PRODUCT="PingFederate"
ENV LICENSE_DIR="${SERVER_ROOT_DIR}/server/default/conf"
ENV LICENSE_FILE_NAME="pingfederate.lic"
ENV LICENSE_SHORT_NAME="PF"
ENV LICENSE_VERSION="9.3"
ENV OPERATIONAL_MODE="STANDALONE"
ENV CLUSTER_BIND_ADDRESS="NON_LOOPBACK"
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh"
ENV TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/server.log
COPY --from=pingidentity/pingcommon /opt ${BASE}
COPY --from=staging /opt ${BASE}

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
#-            pingidentity/pingfederate:edge
#- ```
#- 
#- Follow Docker logs with:
#- 
#- ```
#- docker logs -f pingfederate
#- ```
#- 
#- If using the command above with the embedded [server profile](../server-profiles/README.md), log in with: 
#- * https://localhost:9999/pingfederate/app
#-   * Username: Administrator
#-   * Password: 2FederateM0re
