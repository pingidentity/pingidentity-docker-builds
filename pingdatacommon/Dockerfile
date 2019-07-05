#- # Ping Identity Docker Image - `pingdatacommon`
#- 
#- This docker image provides a busybox image based off of `pingidentity/pingcommon`
#- to house the base hook scripts used throughout 
#- the Ping Identity DevOps PingData product images.  
#-
#- ## Related Docker Images
#- - `pingidentity/pingcommon` - Parent Image
#-

FROM pingidentity/pingcommon
COPY [ "_script-util.sh", "/opt/server/lib/"  ]
COPY [ "hooks/", "/opt/staging/hooks/" ]
