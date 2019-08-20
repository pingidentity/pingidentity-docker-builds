FROM alpine as staging
RUN mkdir -p /opt \
    && cd /opt \
    && apk --no-cache add curl ca-certificates zip gettext \
    && curl -k http://apache.mirrors.ionfish.org/jmeter/binaries/apache-jmeter-5.1.1.zip -o jmeter.zip \
    && unzip jmeter.zip \
    && mv apache-jmeter-* apache-jmeter \
    && find apache-jmeter \( -iname \*.bat -o -iname \*.exe -o -iname \*.dll -o -iname \*.ini \) -exec rm -f {} \; \
    && rm -f jmeter.zip

FROM openjdk:8-jre-alpine
ENV VERBOSE=false
ENV _DOLLAR_="$"
RUN set -x \
    && which apk \
    && apk add --update libintl git
COPY --from=staging /opt/apache-jmeter /opt/apache-jmeter
COPY --from=staging /usr/bin/envsubst /usr/local/bin/envsubst
COPY giterized-entrypoint.sh /
ENTRYPOINT ["/giterized-entrypoint.sh"]
CMD ["--server"]