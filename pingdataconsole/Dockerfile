FROM pingidentity/pingdownloader as staging

# copy your product zip file into the staging image
RUN /get-bits.sh --product pingdirectory --version 7.2.0.0 && \
	unzip -d /tmp/ /tmp/product.zip PingDirectory/resource/admin-console.zip && \
	unzip -d /opt/ /tmp/PingDirectory/resource/admin-console.zip admin-console.war


#
# the final image 
#
FROM tomcat:8-jre8-alpine
LABEL	maintainer=docker@pingidentity.com \
		license="Ping Identity Proprietary" \
		vendor="Ping Identity Corp." \
		name="Ping Identity PingDataConsole (Alpine/OpenJDK8) Image"
EXPOSE 8080
EXPOSE 8443
RUN apk --no-cache add ca-certificates
COPY --from=staging /opt/admin-console.war /usr/local/tomcat/webapps/
CMD ["catalina.sh","run"]