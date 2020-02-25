#- # Ping Identity DevOps Docker Image - `pingtoolkit`
#- 
#- This docker image includes the Ping Identity PingToolkit 
#- and associated hook scripts to create a container that can pull in a SERVER_PROFILE 
#- run scripts.  The typical use case of this image would be an init container or a pod/container
#- to perform tasks aside a running set of pods/containers.
#-
#- ## Related Docker Images
#- - pingidentity/pingbase - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://pingidentity-devops.gitbook.io/devops/docker-images/pingbase)**
#- - pingidentity/pingcommon - Common Ping files (i.e. hook scripts)
#-

ARG SHIM=alpine

#
# The final image 
#
# FROM pingidentity/pingbase:shim-${SHIM}
FROM pingidentity/pingbase:${SHIM}

ENV PING_PRODUCT="PingToolkit"

ENV STARTUP_COMMAND="tail"
ENV STARTUP_FOREGROUND_OPTS="-f /dev/null"

COPY --from=pingidentity/pingcommon /opt ${BASE}

RUN mkdir -p "/opt/server"
COPY [ "liveness.sh", "/opt/"]
COPY [ "hooks/","/opt/staging/hooks/" ]

RUN ./post-build.sh