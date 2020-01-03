#- # Ping Identity DevOps Docker Image - `pingcentral`
#-
#- This docker image includes the Ping Identity PingCentral product binaries
#- and associated hook scripts to create and run PingCentral
#-
#- ## Related Docker Images
#- - pingidentity/pingbase - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://pingidentity-devops.gitbook.io/devops/docker-images/pingbase)**
#- - pingidentity/pingcommon - Common Ping files (i.e. hook scripts)
#- - pingidentity/pingdownloader - Used to download product bits
#-

# TODO use different image before final check-in?
FROM openjdk:11-jre-slim

RUN mkdir /opt/pingcentral
RUN mkdir /opt/pingcentral/bin
RUN mkdir /opt/pingcentral/conf
RUN mkdir /opt/pingcentral/log
RUN mkdir /opt/pingcentral/ext-lib

# Copy files from distribution ZIP
COPY /maven/ping-central.jar /opt/pingcentral/ping-central.jar
COPY /maven/bin/run.sh /opt/pingcentral/bin/run.sh
COPY /maven/bin/obfuscate.sh /opt/pingcentral/bin/obfuscate.sh
COPY /maven/conf/log4j2.xml /opt/pingcentral/conf/log4j2.xml
COPY /maven/conf/pingcentral.lic /opt/pingcentral/conf/pingcentral.lic

# H2 Specific
#COPY /maven/conf/h2/application.properties /opt/pingcentral/conf/application.properties

# MySQL Specific
COPY /maven/conf/mysql/application.properties /opt/pingcentral/conf/application.properties
COPY /maven/conf/mysql/mysql-connector-java-8.0.18.jar /opt/pingcentral/ext-lib/mysql-connector-java-8.0.18.jar

EXPOSE 9022
EXPOSE 3306

ENTRYPOINT [ "/opt/pingcentral/bin/run.sh" ]

# External Database Volume
VOLUME ["/opt/pingcentral/conf/"]

# H2 Specific Volume
#VOLUME ["/opt/pingcentral/conf/", "/opt/pingcentral/h2-data/"]