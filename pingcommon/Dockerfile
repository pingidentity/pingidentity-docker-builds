FROM busybox as pingcommon
RUN mkdir -p ${BASE}/staging/hooks
COPY [ "entrypoint.sh", "lib.sh", "wait-for", "/opt/" ]
COPY [ "10-first-time-sequence.sh", "14-get-remote-server-profile.sh", "15-expand-templates.sh", "16-apply-server-profile.sh", "19-update-server-profile.sh", "/opt/staging/hooks/" ]