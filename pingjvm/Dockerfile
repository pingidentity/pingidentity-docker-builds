ARG SHIM
FROM ${SHIM}:3.11 as jvm-staging
COPY ["build-jvm.sh","/"]
RUN ["/build-jvm.sh"]

FROM scratch
COPY --from=jvm-staging ["/opt/java","/opt/java"]