FROM pingidentity/pingdownloader as staging
ARG PRODUCT=pingfederate
ARG VERSION=9.2.1

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
	&& unzip /tmp/product.zip -d /tmp/ \
	&& mv /tmp/pingfederate-*/pingfederate /opt/server
COPY entrypoint.sh /opt
COPY liveness.sh /opt
COPY run.sh /opt/server/bin/run.sh
COPY utils.sh /opt


#
# the final image 
#
FROM openjdk:8-jre-alpine as pingfederate
LABEL	maintainer=devops_program@pingidentity.com \
		license="Ping Identity Proprietary" \
		vendor="Ping Identity Corp." \
		name="Ping Identity PingFederate (Alpine/OpenJDK8) Image"
EXPOSE 9031
EXPOSE 9999

ENV SERVER_PROFILE_URL=""
ENV SERVER_PROFILE_BRANCH=""
ENV SERVER_PROFILE_PATH=""

RUN apk --no-cache add git curl ca-certificates

VOLUME ["/opt/in"]
# use a separate volume mount as output to persist mutable files
VOLUME ["/opt/out"]

COPY --from=staging /opt /opt
ENTRYPOINT ["/opt/entrypoint.sh"]
