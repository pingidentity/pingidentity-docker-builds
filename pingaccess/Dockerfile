FROM pingidentity/pingdownloader as staging
# place the software being delivered in a conspicuous, unix-correct location
ARG PRODUCT=pingaccess
ARG VERSION=5.2.0

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
	&& unzip /tmp/product.zip -d /tmp/ \
	&& mv /tmp/pingaccess-* /opt/server
COPY entrypoint.sh /opt
COPY run.sh /opt/server/bin/run.sh
COPY postStart.sh /opt
COPY utils.sh /opt
COPY wait-for /opt


#
# the final image 
#
FROM openjdk:8-jre-alpine as pingfederate
LABEL	maintainer=devops_program@pingidentity.com \
		license="Ping Identity Proprietary" \
		vendor="Ping Identity Corp." \
		name="Ping Identity PingAccess (Alpine/OpenJDK8) Image"
EXPOSE 9000
# pingaccess comes ootb listening on 3000 but it is more natural for https traffic to be listened for on 443
EXPOSE 3000
EXPOSE 443

ENV OUT_DIR=/opt/out
ENV IN_DIR=/opt/in
ENV SERVER_PROFILE_URL=""
ENV SERVER_PROFILE_BRANCH=""
ENV SERVER_PROFILE_PATH=""
ENV TAIL_LOG_FILES="pingaccess.log"

RUN apk --no-cache add git curl ca-certificates

VOLUME ${IN_DIR}

# use a separate volume mount as output to persist mutable files
VOLUME ${OUT_DIR}

COPY --from=staging /opt /opt
ENTRYPOINT ["/opt/entrypoint.sh"]
CMD [ "start-server" ]
