FROM pingidentity/pingdownloader as staging
# place the software being delivered in a conspicuous, unix-correct location
RUN mkdir /opt
WORKDIR /opt

# copy your product zip file into the staging image
RUN /get-bits.sh --product pingfederate --version 9.2.0 \
	&& unzip /tmp/product.zip -d /tmp/ \
	&& mv /tmp/pingfederate-*/pingfederate /opt/server
COPY entrypoint.sh /opt
COPY liveness.sh /opt
COPY run.sh /opt/server/bin/run.sh


#
# the final image 
#
FROM openjdk:8-jre-alpine as pingfederate
LABEL	maintainer=docker@pingidentity.com \
		license="Ping Identity Proprietary" \
		vendor="Ping Identity Corp." \
		name="Ping Identity PingFederate (Alpine/OpenJDK8) Image"
EXPOSE 9031
EXPOSE 9999

ENV SERVER_PROFILE_URL=""

RUN apk --no-cache add git curl ca-certificates

VOLUME ["/opt/in"]
# use a separate volume mount as output to persist mutable files
VOLUME ["/opt/out"]

COPY --from=staging /opt /opt
ENTRYPOINT ["/opt/entrypoint.sh"]
