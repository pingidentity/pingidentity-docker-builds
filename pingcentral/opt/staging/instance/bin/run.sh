#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

test "${VERBOSE}" = "true" && set -x

CONFIG_DIR="${SERVER_ROOT_DIR}/conf"
LOG_DIR="${SERVER_ROOT_DIR}/log"
LOG4J2_PROPS="${CONFIG_DIR}/log4j2.xml"
if test -z "${JAVA_OPTS}"; then
    JAVA_OPTS="-XshowSettings:vm -XX:InitialRAMPercentage=${JAVA_RAM_PERCENTAGE} -XX:MinRAMPercentage=${JAVA_RAM_PERCENTAGE} -XX:MaxRAMPercentage=${JAVA_RAM_PERCENTAGE}"
fi

cd "${SERVER_ROOT_DIR}" || exit 99
# Word-split is expected behavior for $JAVA_OPTS. Disable shellcheck.
# shellcheck disable=SC2086
"${JAVA_HOME}"/bin/java -jar ${JAVA_OPTS} \
    --add-opens java.base/java.lang=ALL-UNNAMED \
    --add-opens java.base/java.lang.invoke=ALL-UNNAMED \
    --add-exports java.base/sun.security.util=ALL-UNNAMED \
    --add-exports java.base/sun.security.x509=ALL-UNNAMED \
    -Dlogging.config="${LOG4J2_PROPS}" \
    -Dspring.config.additional-location="file:${CONFIG_DIR}/" \
    -Dpingcentral.jwk="${CONFIG_DIR}/pingcentral.jwk" \
    -Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager \
    -Dlog4j2.AsyncQueueFullPolicy=Discard \
    -Dlog4j2.enable.threadlocals=false \
    -Dlog4j2.DiscardThreshold=INFO \
    -Dpath.applogger.prop="${LOG_DIR}/application.log" \
    -Dpath.apilogger.prop="${LOG_DIR}/application-api.log" \
    -Dpath.extlogger.prop="${LOG_DIR}/application-ext.log" \
    -Dpath.monitorlogger.prop="${LOG_DIR}/monitor.log" \
    -Djava.security.egd=file:/dev/./urandom \
    -Dloader.path="${SERVER_ROOT_DIR}/ext-lib" \
    ping-central.jar "${@}"
