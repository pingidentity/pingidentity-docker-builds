ARG SHIM
ARG DEPS
FROM ${DEPS}${SHIM} as jvm-staging
COPY ["build-jvm.sh","/"]
RUN ["/build-jvm.sh"]

FROM scratch
COPY --from=jvm-staging ["/opt/java","/opt/java"]