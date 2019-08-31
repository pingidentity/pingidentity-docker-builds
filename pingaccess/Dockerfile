#- # Ping Identity DevOps Docker Image - `pingaccess`
#- 
#- This docker image includes the Ping Identity PingAccess product binaries
#- and associated hook scripts to create and run both PingAccess Admin and
#- Engine nodes. 
#-
#- ## Related Docker Images
#- - `pingidentity/pingbase` - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://pingidentity-devops.gitbook.io/devops/docker-images/pingbase)**
#- - `pingidentity/pingcommon` - Common Ping files (i.e. hook scripts)
#- - `pingidentity/pingdownloader` - Used to download product bits
#-
# Default to Alpine
ARG SHIM=alpine

FROM pingidentity/pingdownloader as staging
# place the software being delivered in a conspicuous, unix-correct location
ARG PRODUCT=pingaccess
ARG VERSION=5.2.0

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
	&& unzip /tmp/product.zip -d /tmp/ \
	&& find /tmp -type f \( -iname \*.bat -o -iname \*.dll -o -iname \*.exe \) -exec rm -f {} \; \
	&& mv /tmp/pingaccess-* /opt/server
COPY [ "run.sh", "/opt/server/bin/run.sh" ]
COPY [ "liveness.sh", "/opt/" ]
COPY [ "hooks/","/opt/staging/hooks/" ]

#
# the final image 
#
FROM pingidentity/pingbase:${SHIM}
# pingaccess comes ootb listening on 3000 but it is more natural for https traffic to be listened for on 443
EXPOSE 9000 3000 ${HTTPS_PORT}
ENV PING_PRODUCT="PingAccess"
ENV LICENSE_DIR="${SERVER_ROOT_DIR}/conf"
ENV LICENSE_FILE_NAME=pingaccess.lic
ENV LICENSE_SHORT_NAME=PA
ENV LICENSE_VERSION=5.2
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh"
ENV TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/pingaccess.log
COPY --from=pingidentity/pingcommon "/opt" "${BASE}"
COPY --from=staging "/opt" "${BASE}"

#- ## Running a PingDirectory container
#- To run a PingAccess container: 
#- 
#- ```shell
#-   docker run \
#-            --name pingaccess \
#-            --publish 9000:9000 \
#-            --publish 443:443 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingaccess \
#-            pingidentity/pingaccess:edge
#- ```
#- 
#- 
#- Follow Docker logs with:
#- 
#- ```
#- docker logs -f pingaccess
#- ```
#- 
#- If using the command above with the embedded [server profile](../server-profiles/README.md), log in with: 
#- * https://localhost:9000
#-   * Username: Administrator
#-   * Password: 2Access
