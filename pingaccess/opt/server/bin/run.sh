#!/usr/bin/env sh

DIRNAME=$( dirname "${0}" )
PROGNAME=$( basename "${0}" )

#
# helper to abort.
#
die () {
    (>&2 echo "${*}")
    exit 1
}

#
# Helper to complain.
#
warn () {
    echo "${PROGNAME}: ${*}"
}

# Setup the JVM
JAVA="${JAVA_HOME}/bin/java"
PA_HOME=$( cd "${DIRNAME}/.." || exit 99 ; pwd )
test -z "${PA_HOME}" && exit 99
export PA_HOME
export PA_CONF="${PA_HOME}/conf"
PA_HOME_ESC=$( echo "${PA_HOME}" | awk '{gsub(/ /,"%20");print;}' )

run_props="${PA_CONF}/run.properties"
boot_props="${PA_CONF}/bootstrap.properties"
jvm_memory_opts="${PA_CONF}/jvm-memory.options"

# Check for run.properties (used by PingAccess to configure ports, etc.)
if test ! -f "${run_props}"
then
    warn "Missing run.properties; using defaults."
    run_props=""
fi

# Check for bootstrap.properties (used by PingAccess to configure bootstrapping information for engines)
if test ! -f "${boot_props}"
then
    # warn "Missing bootstrap.properties;"
    boot_props=""
fi

# Check for jvm-memory.options (used by PingAccess to set JVM memory settings)
if test ! -f "${jvm_memory_opts}" 
then
    die "Missing ${jvm_memory_opts}"
fi

#Setup JVM Heap optimizations
JVM_MEMORY_OPTS=$( awk 'BEGIN{OPTS=""} $1!~/^#/{OPTS=OPTS" "$0;} END{print}' <"${jvm_memory_opts}" )

if test "${PING_DEBUG}" = "true"
then
    DEBUG="-Xdebug -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n"
fi

CLASSPATH="${PA_CONF}:${PA_HOME}/lib/*:${PA_HOME}/deploy/*"

cd "${PA_HOME}" || exit 99
# Word-split is expected behavior for $JAVA_OPTS, $JVM_MEMORY_OPTS, and $DEBUG. Disable shellcheck.
# shellcheck disable=SC2086
exec "${JAVA}" \
    -classpath "${CLASSPATH}" \
    ${JAVA_OPTS} ${JVM_MEMORY_OPTS} ${DEBUG} \
    --add-opens java.base/java.lang.invoke=ALL-UNNAMED \
    --add-opens java.base/java.lang=ALL-UNNAMED \
    --add-exports java.base/sun.security.x509=ALL-UNNAMED \
    --add-exports java.base/sun.security.util=ALL-UNNAMED \
    --add-exports java.base/sun.security.provider=ALL-UNNAMED \
    --add-exports java.base/sun.security.pkcs=ALL-UNNAMED \
    -XX:ErrorFile="${PA_HOME_ESC}/log/java_error%p.log" \
    -XX:+HeapDumpOnOutOfMemoryError \
    -XX:HeapDumpPath="${PA_HOME_ESC}/log" \
    -Djava.security.egd=file:/dev/./urandom \
    -Dnet.bytebuddy.experimental=true \
    -Djavax.net.ssl.sessionCacheSize=5000 \
    -Djava.net.preferIPv4Stack=true \
    -Djava.net.preferIPv6Addresses=false \
    -Djava.awt.headless=true \
    -Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager\
    -Dpa.jwk="${PA_CONF}/pa.jwk" \
    -Dpa.jwk.properties="${PA_CONF}/pa.jwk.properties" \
    -Dlog4j.configurationFile="${PA_CONF}/log4j2.xml" \
    -Dlog4j2.AsyncQueueFullPolicy=Discard \
    -Dlog4j2.enable.threadlocals=false \
    -Dlog4j2.DiscardThreshold=INFO \
    -Dhibernate.cache.ehcache.missing_cache_strategy=create \
    -Drun.properties="${run_props}" \
    -Dbootstrap.properties="${boot_props}" \
    -Dpa.home="${PA_HOME}" \
    com.pingidentity.pa.cli.Starter "$@"
