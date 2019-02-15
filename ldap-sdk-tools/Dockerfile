FROM pingidentity/pingdownloader as staging
# place the software being delivered in a conspicuous, unix-correct location
RUN mkdir /opt
WORKDIR /opt

# copy your product zip file into the staging image
RUN /get-bits.sh --product ldapsdk --version 4.0.9 \
	&& unzip /tmp/product.zip -d /tmp/ \
	&& rm /tmp/unboundid-ldapsdk-*/tools/*.bat \
	&& mv /tmp/unboundid-ldapsdk-*/tools /opt/ \
	&& mv /tmp/unboundid-ldapsdk-*/LICENSE* /opt/ \
	&& mv /tmp/unboundid-ldapsdk-*/unboundid-ldapsdk.jar /opt/

RUN rm -f /opt/tools/*.bat

FROM openjdk:8-jre-alpine as pingfederate
LABEL	maintainer=docker@pingidentity.com \
		license="GPLv2, LGPLv2.1, Ping Identity UnboundID LDAP SDK Free Use" \
		vendor="Ping Identity Corp." \
		name="Ping Identity LDAP SDK Tools (Alpine/OpenJDK8) Image"
RUN mkdir /opt
COPY --from=staging /opt /opt
ENV PATH=/opt/tools:${PATH}
WORKDIR /opt/tools
VOLUME ["/opt/out"]