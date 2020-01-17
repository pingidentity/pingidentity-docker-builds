#- # Ping Identity DevOps Docker Image - `pingcentral`
#- 
#- This docker image includes the Ping Identity PingCentral product binaries
#- and associated hook scripts to create and run PingCentral in a container.
#-
#- ## Related Docker Images
#- - pingidentity/pingbase - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://pingidentity-devops.gitbook.io/devops/docker-images/pingbase)**
#- - pingidentity/pingcommon - Common Ping files (i.e. hook scripts)
#- - pingidentity/pingdownloader - Used to download product bits
#-

ARG SHIM=centos

FROM pingidentity/pingdownloader as staging
ARG PRODUCT=pingcentral
ARG VERSION=1.2.0

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
	&& unzip /tmp/product.zip -d /tmp/ \
	&& find /tmp -type f \( -iname \*.bat -o -iname \*.dll -o -iname \*.exe \) -exec rm -f {} \; \
	&& mv /tmp/ping-central-* /opt/server
COPY [ "liveness.sh", "/opt/"]

#
# The final image 
#
FROM pingidentity/pingbase:${SHIM}
EXPOSE 9022
ARG LICENSE_VERSION
ENV PING_PRODUCT="PingCentral"
ENV LICENSE_DIR="${SERVER_ROOT_DIR}/conf"
ENV LICENSE_FILE_NAME="pingcentral.lic"
ENV LICENSE_SHORT_NAME="PC"
ENV LICENSE_VERSION=${LICENSE_VERSION}
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh"
ENV TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/application.log
ENV PING_CENTRAL_LOG_LEVEL="INFO"
ENV PING_CENTRAL_BLIND_TRUST=false
ENV JAVA_HOME=/etc/alternatives/java_sdk
COPY --from=pingidentity/pingcommon /opt ${BASE}
COPY --from=staging /opt ${BASE}

#- ## Running a PingCentral container
#- To run a PingCentral container with your devops configuration file:
#- ```shell docker run -Pt \
#-            --name pingcentral \
#-            --env-file ~/.pingidentity/devops \
#-            pingidentity/pingcentral:edge
#- ```
#- or with long options in the background:
#- ```shell
#-   docker run \
#-            --name pingcentral \
#-            --publish 9022:9022 \
#-            --detach \
#-            --env-file ~/.pingidentity/devops \
#-            pingidentity/pingcentral:edge
#- ```
#- 
#- or if you want to specify everything yourself:
#- ```shell
#-   docker run \
#-            --name pingcentral \
#-            --publish 9022:9022 \
#-            --detach \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER=<yourdevopsuser@example.com> \
#-            --env PING_IDENTITY_DEVOPS_KEY=<yourdevopskeyhere> \
#-            pingidentity/pingcentral:edge
#- ```
#- 
#- Follow Docker logs with:
#- 
#- ``` shell
#- docker logs -f pingcentral
#- ```
#- 
#- If using the command above with the embedded [server profile](../server-profiles/README.md), log in with: 
#- * https://localhost:9022/
#-   * Username: Administrator
#-   * Password: 2Federate

RUN ./post-build.sh