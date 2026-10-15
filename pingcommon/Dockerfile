#- # Ping Identity Docker Image - `pingcommon`
#-
#- This docker image provides a busybox image to house the base hook scripts
#- and default entrypoint.sh used throughout the Ping Identity DevOps product images.
#-
#- Product builds no longer pull scripts from this image (PDI-2523 carrier
#- elimination: they COPY pingcommon/opt/ from the repo-root build context);
#- the image itself is scheduled for retirement in PDI-2524.

#################################################################################

FROM scratch
COPY ["opt/","/opt/"]
