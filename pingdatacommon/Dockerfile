#- # Ping Identity Docker Image - `pingdatacommon`
#-
#- This docker image provides a busybox image based off of `pingidentity/pingcommon`
#- to house the base hook scripts used throughout
#- the Ping Identity DevOps PingData product images.
#-
#- ## Related Docker Images
#- - `pingidentity/pingcommon` - Parent Image
#-
ARG REGISTRY
ARG GIT_TAG
FROM ${REGISTRY}/pingcommon:${GIT_TAG}
# COPY [ "_script-util.sh", "/opt/server/lib/"  ]
# COPY [ "hooks/", "/opt/staging/hooks/" ]
COPY [ "/opt/","/opt/"]
# VOLUME [ "/opt" ]

ONBUILD ENV PD_PROFILE="${STAGING_DIR}/pd.profile"

#-- Flag to force a run of dsjavaproperties --initialize. When this is false,
#-- the java.properties file will only be regenerated on a restart when there
#-- is a change in JVM or a change in the product-specific java options, such
#-- as changing the MAX_HEAP_SIZE value.
ONBUILD ENV REGENERATE_JAVA_PROPERTIES=false