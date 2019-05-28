#- # Ping Identity Docker Image - `apache-jmeter`
#- 
#- This docker image provides an alpine Apache JMeter image
#-
#- ## Related Docker Images
#- - `openjdk:8-jre-alpine` - Alpine with OpenJDK to run Apache JMeter
#-
FROM openjdk:8-jre-alpine
ARG JMETER_VERSION
ENV BASE "/opt"
RUN apk --no-cache add curl ca-certificates zip \
    && curl -k http://apache.mirrors.ionfish.org//jmeter/binaries/apache-jmeter-${JMETER_VERSION}.zip -o ${BASE}/jmeter.zip \
    && cd ${BASE} \
    && unzip jmeter.zip \
    && mv apache-jmeter-* apache-jmeter \
    && find apache-jmeter \( -iname \*.bat -o -iname \*.exe -o -iname \*.dll \) -exec rm -f {} \; \
    && rm -f jmeter.zip \
    && addgroup --system --gid 77783 apache \
    && adduser --system --uid 77797 --ingroup apache --disabled-password --gecos "" --no-create-home --home ${BASE}/apache-jmeter jmeter \
    && chgrp -R apache apache-jmeter \
    && chmod -R 770 apache-jmeter

USER 77797:77783
WORKDIR /opt/apache-jmeter
ENTRYPOINT ["/opt/apache-jmeter/bin/jmeter"]
CMD ["--help"]