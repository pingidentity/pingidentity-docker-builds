FROM pingidentity/pingdownloader as staging
ARG BASE=/opt
ARG PRODUCT=pingfederate
ARG VERSION=9.2.1

# copy your product zip file into the staging image
RUN /get-bits.sh --product ${PRODUCT} --version ${VERSION} \
	&& unzip /tmp/product.zip -d /tmp/ \
	&& find /tmp -type f \( -iname \*.bat -o -iname \*.dll -o -iname \*.exe \) -exec rm -f {} \; \
	&& mv /tmp/pingfederate-*/pingfederate /opt/server
COPY [ "liveness.sh", "${BASE}/"]
COPY [ "run.sh", "/opt/server/bin/run.sh" ]


#
# the final image 
#
FROM pingidentity/pingbase
EXPOSE 9031 9999
ENV STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh"
ENV TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/server.log
COPY --from=pingidentity/pingcommon ${BASE} ${BASE}
COPY --from=staging ${BASE} ${BASE}