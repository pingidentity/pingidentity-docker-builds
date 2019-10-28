#- # Ping Identity Docker Image - `pingdataconsole`
#- 
#- This docker image provides a tomcat image with the PingDataConsole
#- deployed to be used in configuration of the PingData products.
#-
#- ## Related Docker Images
#- - `pingidentity/pingdownloader` - Image used to download ping product
#- - `tomcat:8-jre8-alpine` - Tomcat engine to serve PingDataConsole .war file
#-

FROM pingidentity/pingdownloader as staging
ARG PRODUCT=pingdirectory
ARG VERSION=7.3.0.3
# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
	&& unzip -d /tmp/ /tmp/product.zip PingDirectory/resource/admin-console.zip \
	&& unzip -d /tmp/ /tmp/PingDirectory/resource/admin-console.zip admin-console.war \
    && mkdir /opt/console \
    && unzip -d /opt/console /tmp/admin-console.war

#
# the final image 
#
FROM tomcat:8-jre8-alpine
LABEL	maintainer=devops_program@pingidentity.com \
		license="Ping Identity Proprietary" \
		vendor="Ping Identity Corp." \
		name="Ping Identity PingDataConsole (Alpine/OpenJDK8) Image"
EXPOSE 8443
RUN apk --no-cache add curl ca-certificates \
    && rm -rf /usr/local/tomcat/webapps/* \
    && mkdir -p /usr/local/tomcat/webapps/ROOT \
    && mkdir -p /opt/in

COPY --from=staging /opt/console /usr/local/tomcat/webapps/console
COPY index.html /usr/local/tomcat/webapps/ROOT/
COPY server.xml /usr/local/tomcat/conf/
COPY keystore /opt/in/
COPY [ "liveness.sh", "/usr/local/bin/" ]
HEALTHCHECK --interval=31s --timeout=30s --start-period=5s --retries=3 CMD [ "/usr/local/bin/liveness.sh" ]
CMD ["catalina.sh","run"]

#- ## Run
#- To run a PingDataConsole container: 
#- 
#- ```shell
#-   docker run \
#-            --name pingdataconsole \
#-            --publish 8443:8443 \
#-            --detach \
#-            pingidentity/pingdataconsole
#- ```
#- 
#- 
#- Follow Docker logs with:
#- 
#- ```
#- docker logs -f pingdataconsole
#- ```
#- 
#- If using the command above with the embedded [server profile](../server-profiles/README.md), log in with: 
#- * http://localhost:8443/console/login
#- ```
#- Server: pingdirectory
#- Username: administrator
#- Password: 2FederateM0re
#- ```
#- >make sure you have a PingDirectory running
