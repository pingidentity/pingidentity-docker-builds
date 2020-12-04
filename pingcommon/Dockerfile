#- # Ping Identity Docker Image - `pingcommon`
#-
#- This docker image provides a busybox image to house the base hook scripts
#- and default entrypoint.sh used throughout the Ping Identity DevOps product images.
#-
#-

# This substrate layer will gather common bits for all images
#  like su-exec and tini
ARG DEPS
FROM ${DEPS}alpine:3.12.1 as substrate
COPY ["common-build.sh","/"]
RUN ["/common-build.sh"]

FROM scratch
COPY --from=substrate ["/opt","/opt"]
COPY ["opt/","/opt/"]
# RUN mkdir -p ${BASE}/staging/hooks
# COPY [ "post-build.sh", "bootstrap.sh", "entrypoint.sh", "wait-for", ".profile", "/opt/" ]
# COPY [ "hooks/", "/opt/staging/hooks/" ]

# FROM scratch
# COPY --from=staging ["/opt/","/opt/"]
