#- # Ping Identity Docker Image - `pingdatacommon`
#-
#- This docker image houses the PingData hook scripts used throughout
#- the Ping Identity DevOps PingData product images.
#-
#- Product builds no longer pull scripts from this image (PDI-2523 carrier
#- elimination: they COPY pingdatacommon/opt/ from the repo-root build
#- context); the image itself is scheduled for retirement in PDI-2524.

#################################################################################

FROM scratch
COPY ["opt/","/opt/"]
