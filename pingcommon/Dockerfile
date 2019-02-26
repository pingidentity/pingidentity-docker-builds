FROM busybox as pingcommon
ARG BASE=/opt
RUN mkdir -p ${BASE}/staging/hooks
COPY [ "entrypoint.sh", "lib.sh", "wait-for", "${BASE}/" ]
COPY [ "10-first-time-sequence.sh", "14-get-remote-server-profile.sh", "16-apply-server-profile.sh", "19-update-server-profile.sh", "${BASE}/staging/hooks/" ]