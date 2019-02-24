FROM pingidentity/pingdownloader as staging
ARG BASE=/opt
# place the software being delivered in a conspicuous, unix-correct location
ARG PRODUCT=pingaccess
ARG VERSION=5.2.0

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
	&& unzip /tmp/product.zip -d /tmp/ \
	&& find /tmp -type f \( -iname \*.bat -o -iname \*.dll -o -iname \*.exe \) -exec rm -f {} \; \
	&& mv /tmp/pingaccess-* ${BASE}/server
COPY [ "run.sh", "/opt/server/bin/run.sh" ]

#
# the final image 
#
FROM pingidentity/pingbase
EXPOSE 9000
# pingaccess comes ootb listening on 3000 but it is more natural for https traffic to be listened for on 443
EXPOSE 3000
EXPOSE 443
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh"
ENV TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/pingaccess.log
COPY --from=pingidentity/pingcommon ${BASE} ${BASE}
COPY --from=staging ${BASE} ${BASE}
