#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

test "${VERBOSE}" = "true" && set -x

##  PingAccess Docker Bootstrap Script
PROGNAME=$(basename "${0}")
# a function to display warnings in a f
warn() {
    printf "%s: %s" "${PROGNAME}" "${*}"
}

# Helper to fail.
die() {
    warn "${@}"
    exit 1
}

PA_HOME_ESC=$(echo "${SERVER_ROOT_DIR}" | awk '{gsub(/ /,"%20");print;}')

PA_CONF="${SERVER_ROOT_DIR}/conf"
run_props="${PA_CONF}/run.properties"
boot_props="${PA_CONF}/bootstrap.properties"

# Check for run.properties (used by PingAccess to configure ports, etc.)
if test ! -f "${run_props}"; then
    warn "Missing run.properties; using defaults."
    run_props=""
fi

# Check for bootstrap.properties (used by PingAccess to configure bootstrapping information for engines)
if test ! -f "${boot_props}"; then
    # warn "Missing bootstrap.properties;"
    boot_props=""
fi

#Setup JVM Heap optimizations
if test -z "${JAVA_OPTS}"; then
    # Check for jvm-memory.options (used by PingAccess to set JVM memory settings)
    jvm_memory_opts="${PA_CONF}/jvm-memory.options"
    if test ! -f "${jvm_memory_opts}"; then
        die "Missing ${jvm_memory_opts}"
    fi
    JAVA_OPTS=$(awk 'BEGIN{OPTS=""} $1!~/^#/{OPTS=OPTS" "$0;} END{print OPTS}' < "${jvm_memory_opts}")
fi

if test "${PING_DEBUG}" = "true"; then
    JVM_OPTS="-Xdebug -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n"
fi

CLASSPATH="${PA_CONF}:${SERVER_ROOT_DIR}/lib/*:${SERVER_ROOT_DIR}/deploy/*"

cd "${SERVER_ROOT_DIR}" || exit 99
# Word-split is expected behavior for $JAVA_OPTS, $JVM_OPTS. Disable shellcheck.
# shellcheck disable=SC2086
exec "${JAVA_HOME}"/bin/java ${JAVA_OPTS} ${JVM_OPTS} \
    --add-opens java.base/java.lang=ALL-UNNAMED \
    --add-opens java.base/java.lang.invoke=ALL-UNNAMED \
    --add-opens java.base/sun.security.internal.spec=ALL-UNNAMED \
    --add-opens java.base/sun.security.x509=ALL-UNNAMED \
    --add-opens java.base/sun.security.util=ALL-UNNAMED \
    --add-opens java.base/sun.security.pkcs10=ALL-UNNAMED \
    --add-opens java.base/sun.security.pkcs=ALL-UNNAMED \
    --add-exports java.base/sun.security.provider=ALL-UNNAMED \
    -XX:ErrorFile="${PA_HOME_ESC}/log/java_error%p.log" \
    -XX:+HeapDumpOnOutOfMemoryError \
    -XX:HeapDumpPath="${PA_HOME_ESC}/log" \
    -Djava.security.egd=file:/dev/./urandom \
    -Dnet.bytebuddy.experimental=true \
    -Djavax.net.ssl.sessionCacheSize=5000 \
    -Djava.net.preferIPv4Stack=true \
    -Djava.net.preferIPv6Addresses=false \
    -Djava.awt.headless=true \
    -Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager \
    -Dpa.jwk="${PA_CONF}/pa.jwk" \
    -Dpa.jwk.properties="${PA_CONF}/pa.jwk.properties" \
    -Dlog4j.configurationFile="${PA_CONF}/log4j2.xml" \
    -Dlog4j2.AsyncQueueFullPolicy=Discard \
    -Dlog4j2.enable.threadlocals=false \
    -Dlog4j2.DiscardThreshold=INFO \
    -Dhibernate.cache.ehcache.missing_cache_strategy=create \
    -Drun.properties="${run_props}" \
    -Dbootstrap.properties="${boot_props}" \
    -Dpa.home="${SERVER_ROOT_DIR}" \
    -classpath "${CLASSPATH}" \
    com.pingidentity.pa.cli.Starter "$@"
