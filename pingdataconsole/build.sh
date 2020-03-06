#!/usr/bin/env sh
set -x

company=pingidentity
image=pingdataconsole
tag=edge
BITS_VERSION=8.0.0.1
prefix=SERVER_PROFILE
originalImage="tomcat:8-jre8-alpine"

docker pull ${originalImage}
originalEntrypoint=$( docker image inspect ${originalImage} --format '{{join .Config.Entrypoint " "}}' )
originalCmd=$( docker image inspect ${originalImage} --format '{{join .Config.Cmd " "}}' )

docker build \
    --build-arg "VERSION=${BITS_VERSION}" \
    ${originalEntrypoint:+--build-arg "ORIGINAL_ENTRYPOINT=${originalEntrypoint}"} \
    ${originalCmd:+--build-arg "ORIGINAL_CMD=${originalCmd}"} \
    ${prefix:+--build-arg GIT_PREFIX=${prefix}} \
    -t ${company}/${image}:${tag} \
    .

