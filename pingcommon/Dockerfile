FROM busybox as pingcommon
ARG BASE=/opt
RUN mkdir -p ${BASE}
COPY ["entrypoint.sh","utils.sh","wait-for","${BASE}/"]