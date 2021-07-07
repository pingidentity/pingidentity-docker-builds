#- # Ping Identity Docker Image - `ldap-sdk-tools`
#-
#- This docker image provides an alpine image with the LDAP Client
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
ARG DEPS
ARG GIT_TAG
ARG ARCH

FROM ${REGISTRY}/${PRODUCT}:staging-${VERSION}-${GIT_TAG} as product-staging
FROM ${REGISTRY}/pingcommon:${GIT_TAG}-${ARCH} as common
FROM ${REGISTRY}/pingjvm:${JVM}-${SHIM_TAG}-${GIT_TAG}-${ARCH} as jvm

FROM ${DEPS}${SHIM} as final-staging

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
FROM ${REGISTRY}/pingbase:${GIT_TAG}-${ARCH}
# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
    PATH=/opt/tools:${PATH}

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL   image-version="${IMAGE_VERSION}" \
        image-git-rev="${IMAGE_GIT_REV}" \
		maintainer=devops_program@pingidentity.com \
		license="Apache License v2.0, GPLv2, LGPLv2.1, Ping Identity UnboundID LDAP SDK Free Use" \
		vendor="Ping Identity Corp." \
		name="Ping Identity LDAP SDK Tools (Alpine/OpenJDK8) Image"
VOLUME ["/opt/out"]
COPY --from=final-staging ["/","/"]

#- ## List all available tools
#- `docker run -it --rm pingidentity/ldap-sdk-tools:edge ls`
#-
#- ## Use LDAPSearch
#- ### Get some help
#- `docker run -it --rm pingidentity/ldap-sdk-tools:edge ldapsearch --help`
#-
#- ### Simple search
#- ```Bash
#- docker run -it --rm pingidentity/ldap-sdk-tools:edge \
#-     ldapsearch \
#-         -b dc=example,dc=com \
#-         -p 1389 "(objectClass=*)"
#- ```
#-
#- ### Save output to host file
#- ```Bash
#- docker run -it --rm \
#-     -v /tmp:/opt/out \
#-     pingidentity/ldap-sdk-tools:edge \
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
#-   pingidentity/ldap-sdk-tools:edge \
#-   manage-certificates trust-server-certificate \
#-     --hostname haveibeenpwned.com \
#-     --port 1443 \
#-     --keystore /opt/out/hibp-2019.jks \
#-     --keystore-password ${PWD}
#- ls -all /tmp/hibp
#- keytool -list \
#-   -keystore /tmp/hibp/hibp-2019.jks \
#-   -storepass ${PWD}
#- ```
