#- # Ping Identity Docker Image - `pingdataconsole`
#- 
#- This docker image provides an apine image with the LDAP Client
#- SDK tools to be used against other PingDirectory instances.
#-
#- ## Related Docker Images
#- - `pingidentity/pingdownloader` - Image used to download ping product
#- - `openjdk:8-jre8-alpine` - Alpine server to run LDAP SDK Tools from
#-

FROM pingidentity/pingdownloader as staging

# copy your product zip file into the staging image
RUN /get-bits.sh --product ldapsdk --version 4.0.14 \
	&& unzip /tmp/product.zip -d /tmp/ \
	&& rm /tmp/unboundid-ldapsdk-*/tools/*.bat \
	&& mv /tmp/unboundid-ldapsdk-*/tools /opt/ \
	&& mv /tmp/unboundid-ldapsdk-*/LICENSE* /opt/ \
	&& mv /tmp/unboundid-ldapsdk-*/unboundid-ldapsdk.jar /opt/
COPY wait-for /opt/tools/

FROM azul/zulu-openjdk-alpine:11 as jvm
ENV JDK_HOME=/usr/lib/jvm/default-jvm 
ENV JDK_MODULES=${JDK_HOME}/jmods/ 
RUN ${JDK_HOME}/bin/jlink \
    --compress=2 \
    --no-header-files \
    --no-man-pages \
    --strip-debug \
    --module-path ${JDK_MODULES} \
    --add-modules java.base,java.logging,java.naming,java.security.sasl \
    --output /opt/java

# FROM openjdk:8-jre-alpine as ldapsdk
FROM alpine
LABEL	maintainer=devops_program@pingidentity.com \
		license="GPLv2, LGPLv2.1, Ping Identity UnboundID LDAP SDK Free Use" \
		vendor="Ping Identity Corp." \
		name="Ping Identity LDAP SDK Tools (Alpine/OpenJDK8) Image"
COPY --from=staging ["/opt","/opt"]
COPY --from=jvm ["/opt/java","/opt/java"]

ENV JAVA_HOME=/opt/java
ENV PATH=/opt/tools:${JAVA_HOME}/bin:${PATH}
WORKDIR /opt/tools
VOLUME ["/opt/out"]

#- ## List all available tools
#- `docker run -it --rm pingidentity/ldap-sdk-tools ls`
#- 
#- ## Use LDAPSearch
#- ### Get some help
#- `docker run -it --rm pingidentity/ldap-sdk-tools ldapsearch --help`
#- 
#- ### Simple search
#- ```Bash
#- docker run -it --rm pingidentity/ldap-sdk-tools \
#-     ldapsearch \
#-         -b dc=example,dc=com \
#-         -p 1389 "(objectClass=*)"
#- ```
#- 
#- ### Save output to host file
#- ```Bash
#- docker run -it --rm \
#-     -v /tmp:/opt/out \
#-     pingidentity/ldap-sdk-tools \
#-     ldapsearch \
#-         --baseDN dc=example,dc=com \
#-         --port 1389 \
#-         --outputFormat json "(objectClass=*)" >/tmp/search-result.json
#- ```
#- 
#- ## Use manage-certificates
#- ### trusting certificates
#- ```Bash
#- PWD=2FederateM0re
#- mkdir -p /tmp/hibp
#- docker run -it --rm \
#-   -v /tmp/hibp:/opt/out \
#-   pingidentity/ldap-sdk-tools \
#-   manage-certificates trust-server-certificate \
#-     --hostname haveibeenpwned.com \
#-     --port 443 \
#-     --keystore /opt/out/hibp-2019.jks \
#-     --keystore-password ${PWD}
#- ls -all /tmp/hibp
#- keytool -list \
#-   -keystore /tmp/hibp/hibp-2019.jks \
#-   -storepass ${PWD}
#- ```
