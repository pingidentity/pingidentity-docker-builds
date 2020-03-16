#- # Ping Identity Docker Image - `pingdataconsole`
#- 
#- This docker image provides an apine image with the LDAP Client
#- SDK tools to be used against other PingDirectory instances.
#-
#- ## Related Docker Images
#- - `pingidentity/pingdownloader` - Image used to download ping product
#- - `openjdk:8-jre8-alpine` - Alpine server to run LDAP SDK Tools from
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
FROM ${REGISTRY}/pingjvm:${JVM}_${SHIM_TAG}-${GIT_TAG} as jvm

FROM ${SHIM} as final-staging
ENV SHIM=${SHIM}

# get the product bits FIRST
COPY --from=product-staging ["/opt/","/opt/"]

# get Ping-wide common scripts
#   this needs to happen after the bits have been laid down
#   so they can be patched
COPY --from=common ["/opt/","/opt/"]

# get the jvm
COPY --from=jvm ["/opt/java","/opt/java"]

# apply product-specific hooks and patches
COPY ["/opt","/opt"]

# Run build
RUN ["/opt/build.sh"]

#
# the final image 
#
FROM ${REGISTRY}/pingbase:${GIT_TAG}
LABEL	maintainer=devops_program@pingidentity.com \
		license="Apache License v2.0, GPLv2, LGPLv2.1, Ping Identity UnboundID LDAP SDK Free Use" \
		vendor="Ping Identity Corp." \
		name="Ping Identity LDAP SDK Tools (Alpine/OpenJDK8) Image"
ENV PATH=/opt/tools:${PATH}
VOLUME ["/opt/out"]
COPY --from=final-staging ["/","/"]

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
