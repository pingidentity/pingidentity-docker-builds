ARG SHIM
ARG DEPS
ARG VERBOSE
FROM ${DEPS}${SHIM} as jvm-staging
ENV VERBOSE=${VERBOSE}
COPY ["build-jvm.sh","/"]
RUN ["/build-jvm.sh"]

FROM scratch
COPY --from=jvm-staging ["/opt/java","/opt/java"]