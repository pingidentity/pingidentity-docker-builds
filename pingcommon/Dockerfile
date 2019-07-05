#- # Ping Identity Docker Image - `pingcommon`
#- 
#- This docker image provides a busybox image to house the base hook scripts
#- and default entrypoint.sh used throughout the Ping Identity DevOps product images.  
#-
#-

FROM busybox as pingcommon
RUN mkdir -p ${BASE}/staging/hooks
COPY [ "entrypoint.sh", "wait-for", "/opt/" ]
COPY [ "hooks/", "/opt/staging/hooks/" ]
