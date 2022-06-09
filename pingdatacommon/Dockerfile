#- # Ping Identity Docker Image - `pingdatacommon`
#-
#- This docker image provides a busybox image based off of `pingidentity/pingcommon`
#- to house the base hook scripts used throughout
#- the Ping Identity DevOps PingData product images.
#-
#- ## Related Docker Images
#- - `pingidentity/pingcommon` - Parent Image
#-

#################################################################################

# # Top level ARGS used in all FROM commands
ARG REGISTRY
ARG GIT_TAG
ARG ARCH

#################################################################################

# The final image
FROM ${REGISTRY}/pingcommon:${GIT_TAG}-${ARCH}
COPY [ "/opt/","/opt/"]

#-- Flag to force a run of dsjavaproperties --initialize. When this is false,
#-- the java.properties file will only be regenerated on a restart when there
#-- is a change in JVM or a change in the product-specific java options, such
#-- as changing the MAX_HEAP_SIZE value.
ENV REGENERATE_JAVA_PROPERTIES=false
