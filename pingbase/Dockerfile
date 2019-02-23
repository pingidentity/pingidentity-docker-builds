FROM openjdk:8-jre-alpine
ONBUILD LABEL	maintainer=devops_program@pingidentity.com \
		license="Ping Identity Proprietary" \
		vendor="Ping Identity Corp." \
		name="Ping Identity (Alpine/OpenJDK8) Image"
ONBUILD RUN apk --no-cache add git curl ca-certificates jq \
    && apk add --update libintl \
    && apk add --virtual build_deps gettext \
    && cp /usr/bin/envsubst /usr/local/bin/envsubst \
    && apk del build_deps
ONBUILD ARG BASE
ONBUILD ENV BASE=${BASE:-/opt}
ONBUILD ENV IN_DIR=${BASE}/in
ONBUILD ENV OUT_DIR=${BASE}/out
ONBUILD ENV BAK_DIR=${BASE}/backup
ONBUILD ENV SERVER_PROFILE_URL=""
ONBUILD ENV SERVER_PROFILE_BRANCH=""
ONBUILD ENV SERVER_PROFILE_PATH=""
ONBUILD ENV SERVER_ROOT_DIR=${OUT_DIR}/instance
ONBUILD ENV PATH="${SERVER_ROOT_DIR}/bin:${PATH}"
ONBUILD VOLUME [ "${BAK_DIR}", "${IN_DIR}", "${OUT_DIR}" ]
ONBUILD WORKDIR ${BASE}
ONBUILD ENTRYPOINT [ "/opt/entrypoint.sh" ]
ONBUILD CMD [ "start-server" ]