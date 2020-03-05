FROM alpine as staging
COPY keys.gpg /tmp
RUN mkdir -p /opt \
    && cd /opt \
    && apk --no-cache add gnupg gettext \
    && export _payload="apache-jmeter-5.2.1" \
    && wget -S -T 1 http://mirrors.sonic.net/apache//jmeter/binaries/${_payload}.tgz \
    && wget -S -T 1 https://www.apache.org/dist/jmeter/binaries/${_payload}.tgz.asc \
    && ls \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver pgpkeys.mit.edu --recv-key DE885DD3 \
    && gpg --import /tmp/keys.gpg \
    && gpg --batch --verify ${_payload}.tgz.asc ${_payload}.tgz \
    && tar xzf ${_payload}.tgz \
    && mv ${_payload} apache-jmeter \
    && find apache-jmeter \( -iname \*.bat -o -iname \*.exe -o -iname \*.dll -o -iname \*.ini \) -exec rm -f {} \; \
    && rm -rf apache-jmeter/printable_docs apache-jmeter/docs apache-jmeter/licenses apache-jmeter/LICENSE apache-jmeter/NOTICE apache-jmeter/README.md

FROM azul/zulu-openjdk-alpine:11 as jvm
ENV JDK_HOME=/usr/lib/jvm/default-jvm 
ENV JDK_MODULES=${JDK_HOME}/jmods/ 
RUN ${JDK_HOME}/bin/jlink \
    --compress=2 \
    --no-header-files \
    --no-man-pages \
    --strip-debug \
    --module-path ${JDK_MODULES} \
    --add-modules java.base,java.logging,java.xml \
    --output /opt/java

FROM alpine
ENV VERBOSE=false
ENV _DOLLAR_="$"
RUN set -x \
    && type apk >/dev/null 2>/dev/null \
    && apk add --no-cache libintl git
COPY --from=staging ["/opt/apache-jmeter","/opt/apache-jmeter"]
COPY --from=staging ["/usr/bin/envsubst","/usr/local/bin/envsubst"]
COPY --from=jvm ["/opt/java","/opt/java"]
COPY giterized-entrypoint.sh /
ENV JAVA_HOME="/opt/java"
ENV PATH=${JAVA_HOME}/bin:${PATH}
ENTRYPOINT ["/giterized-entrypoint.sh"]
CMD ["--server"]
