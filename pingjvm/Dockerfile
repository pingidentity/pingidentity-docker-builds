# Top level ARGS used in all FROM commands
ARG SHIM
ARG DEPS

FROM ${DEPS}${SHIM} as jvm-staging

# Arguments used in build-jvm.sh
ARG VERBOSE
ARG JVM_ID

COPY ["build-jvm.sh","/"]

RUN ["/build-jvm.sh"]

FROM scratch
COPY --from=jvm-staging ["/opt/java","/opt/java"]
