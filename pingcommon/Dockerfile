FROM busybox as pingcommon
RUN mkdir -p ${BASE}/staging/hooks
COPY [ "entrypoint.sh", "lib.sh", "wait-for", "/opt/" ]
COPY [ "hooks/", "/opt/staging/hooks/" ]
