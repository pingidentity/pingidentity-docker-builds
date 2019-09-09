FROM busybox
ARG BASE
ENV BASE ${BASE:-/opt}
RUN mkdir -p ${BASE}
COPY doh ${BASE}