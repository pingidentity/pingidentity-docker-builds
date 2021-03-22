#- # Ping Identity DevOps Docker Image - `pingtoolkit`
#-
#- This docker image includes the Ping Identity PingToolkit
#- and associated hook scripts to create a container that can pull in a SERVER_PROFILE
#- run scripts.  The typical use case of this image would be an init container or a pod/container
#- to perform tasks aside a running set of pods/containers.
#-
#- ## Related Docker Images
#- - `pingidentity/pingbase` - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)**
#- - `pingidentity/pingcommon` - Common Ping files (i.e. hook scripts)
#-
ARG PRODUCT
ARG SHIM
ARG SHIM_TAG
# ARG VERSION
ARG JVM
ARG REGISTRY
ARG DEPS
ARG GIT_TAG

FROM ${REGISTRY}/pingcommon:${GIT_TAG} as common
FROM ${REGISTRY}/pingjvm:${JVM}_${SHIM_TAG}-${GIT_TAG} as jvm

FROM ${DEPS}${SHIM} as final-staging
ENV SHIM=${SHIM}

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
# The final image
#
FROM ${REGISTRY}/pingbase:${GIT_TAG}
#-- Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ENV IMAGE_VERSION=${IMAGE_VERSION}
ARG IMAGE_GIT_REV=""
ENV IMAGE_GIT_REV=${IMAGE_GIT_REV}

LABEL image-version="${IMAGE_VERSION}" \
      image-git-rev="${IMAGE_GIT_REV}"

ENV PING_PRODUCT="PingToolkit"
ENV STARTUP_COMMAND="tail"
ENV STARTUP_FOREGROUND_OPTS="-f /dev/null"
COPY --from=final-staging ["/","/"]