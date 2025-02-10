#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

test "${VERBOSE}" = "true" && set -x

##  PingFederate Docker Bootstrap Script
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

# Helper to check required files
require() {
    _requiredFile=${1}
    shift
    if ! test -f "${_requiredFile}"; then
        die "Missing required file: ${_requiredFile}"
    fi
}

PF_BIN="${SERVER_ROOT_DIR}/bin"
# Read an optional running configuration file
test -z "${RUN_CONF}" && RUN_CONF="${PF_BIN}/run.conf"

if test -r "${RUN_CONF}"; then
    # shellcheck disable=SC1090
    . "${RUN_CONF}"
fi

PF_SERVER_HOME="${SERVER_ROOT_DIR}/server/default"
PF_SERVER_LIB="${PF_SERVER_HOME}/lib"

# Set PF_HOME_ESC - this is PF_HOME but with spaces that are replaced with %20
PF_HOME_ESC=$(echo "${SERVER_ROOT_DIR}" | awk '{gsub(/ /,"%20");print;}')

# Setup the classpath
pf_run_jar="${PF_BIN}/pf-startup.jar"
xmlbeans="${PF_SERVER_LIB}/xmlbeans.jar"
pf_xml="${PF_SERVER_LIB}/pf-xml.jar"
PF_BOOT_CLASSPATH="${PF_HOME_ESC}/startup/*"
for requiredFile in ${pf_run_jar} ${xmlbeans} ${pf_xml}; do
    require "${requiredFile}"
    PF_BOOT_CLASSPATH="${PF_BOOT_CLASSPATH}${PF_BOOT_CLASSPATH:+:}${requiredFile}"
done

pf_console_util="${PF_BIN}/pf-consoleutils.jar"
pf_crypto_luna="${PF_SERVER_LIB}/pf-crypto-luna.jar"
pf_fips="${SERVER_ROOT_DIR}/lib/bc-fips-1.0.2.jar"

PF_BOOT_CLASSPATH="${PF_BOOT_CLASSPATH}${PF_BOOT_CLASSPATH:+:}${pf_console_util}:${pf_crypto_luna}:${pf_fips}"

PF_CLASSPATH="${PF_CLASSPATH}${PF_CLASSPATH:+:}${PF_BOOT_CLASSPATH}"

if test -z "${JAVA_OPTS}"; then
    jvm_memory_opts="${PF_BIN}/jvm-memory.options"
    require "${jvm_memory_opts}"
    JAVA_OPTS=$(awk 'BEGIN{OPTS=""} $1!~/^#/{OPTS=OPTS" "$0;} END{print OPTS}' < "${jvm_memory_opts}")
fi

# Debugger arguments
if test "${PING_DEBUG}" = "true" || test "${PF_ENGINE_DEBUG}" = "true" || test "${PF_ADMIN_DEBUG}" = "true"; then
    JVM_OPTS="${JVM_OPTS:-${JVM_OPTS} }-Xdebug -Xrunjdwp:transport=dt_socket,address=${PF_DEBUG_PORT},server=y,suspend=n"
fi

# Check for run.properties (used by PingFederate to configure ports, etc.)
run_props="${PF_BIN}/run.properties"
if ! test -r "${run_props}"; then
    warn "Missing run.properties; using defaults."
    run_props=""
fi

JAVA_VERSION=$("${JAVA_HOME}/bin/java" -version 2>&1 | grep "version" | head -n 1 | cut -d\" -f 2)
JAVA_MAJOR_VERSION=$(echo "${JAVA_VERSION}" | sed -e 's/_/./' | cut -d. -f 1)

# java 17 support
if test "${JAVA_MAJOR_VERSION}" = "17"; then
    JAVA_OPTS="${JAVA_OPTS} --add-opens=java.base/java.lang=ALL-UNNAMED"
    JAVA_OPTS="${JAVA_OPTS} --add-opens=java.base/java.util=ALL-UNNAMED"
    JAVA_OPTS="${JAVA_OPTS} --add-exports=java.base/sun.security.x509=ALL-UNNAMED"
    JAVA_OPTS="${JAVA_OPTS} --add-exports=java.base/sun.security.util=ALL-UNNAMED"
    JAVA_OPTS="${JAVA_OPTS} --add-exports=java.naming/com.sun.jndi.ldap=ALL-UNNAMED"
    JAVA_OPTS="${JAVA_OPTS} --add-exports=java.base/sun.net.util=ALL-UNNAMED"
    JAVA_OPTS="${JAVA_OPTS} --add-exports=java.base/sun.security.pkcs=ALL-UNNAMED"
    JAVA_OPTS="${JAVA_OPTS} --add-exports=java.base/sun.security.pkcs10=ALL-UNNAMED"
fi

# Word-split is expected behavior for $JAVA_OPTS and $JVM_OPTS. Disable Shellcheck
# shellcheck disable=SC2086
exec "${JAVA_HOME}"/bin/java ${JAVA_OPTS} ${JVM_OPTS} \
    -Dprogram.name="${PROGNAME}" \
    -Djava.security.egd=file:/dev/./urandom \
    -Dorg.bouncycastle.fips.approved_only="${PF_BC_FIPS_APPROVED_ONLY}" \
    -Dlog4j2.AsyncQueueFullPolicy=Discard \
    -Dlog4j2.DiscardThreshold=INFO \
    -XX:+HeapDumpOnOutOfMemoryError \
    -XX:-OmitStackTraceInFastThrow \
    -Dcom.ncipher.provider.announcemode=on \
    -XX:HeapDumpPath="${PF_HOME_ESC}/log" \
    -XX:ErrorFile="${PF_HOME_ESC}/log/java_error%p.log" \
    -Dlog4j.configurationFile="${PF_HOME_ESC}/server/default/conf/log4j2.xml" \
    -Drun.properties="${run_props}" \
    -Dpf.home="${SERVER_ROOT_DIR}" \
    -Djetty.home="${SERVER_ROOT_DIR}" \
    -Djetty.base="${PF_BIN}" \
    -Djetty.server=com.pingidentity.appserver.jetty.PingFederateInit \
    -Dpf.server.default.dir="${PF_SERVER_HOME}" \
    -Dpf.java="${JAVA}" \
    -Dpf.java.opts="-Drun.properties=${run_props}" \
    -Dpf.classpath="${PF_CLASSPATH}" \
    -Djava.library.path="${PF_HOME_ESC}/startup" \
    -classpath "${PF_CLASSPATH}" \
    org.pingidentity.RunPF "${@}"
