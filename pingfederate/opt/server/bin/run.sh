#!/usr/bin/env sh
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
# shellcheck disable=SC1090
test -r "${RUN_CONF}" && . "${RUN_CONF}"

PF_SERVER_HOME="${SERVER_ROOT_DIR}/server/default"
PF_SERVER_LIB="${PF_SERVER_HOME}/lib"

# Set PF_HOME_ESC - this is PF_HOME but with spaces that are replaced with %20
PF_HOME_ESC=$(echo "${SERVER_ROOT_DIR}" | awk '{gsub(/ /,"%20");print;}')

# Setup the classpath
run_jar="${PF_BIN}/run.jar"
pf_run_jar="${PF_BIN}/pf-startup.jar"
jetty_starter_jar="${PF_BIN}/jetty-start.jar"
xmlbeans="${PF_SERVER_LIB}/xmlbeans.jar"
pf_xml="${PF_SERVER_LIB}/pf-xml.jar"
PF_BOOT_CLASSPATH=""
for requiredFile in ${run_jar} ${pf_run_jar} ${jetty_starter_jar} ${xmlbeans} ${pf_xml}; do
    require "${requiredFile}"
    PF_BOOT_CLASSPATH="${PF_BOOT_CLASSPATH}${PF_BOOT_CLASSPATH:+:}${requiredFile}"
done

pf_console_util="${PF_BIN}/pf-consoleutils.jar"
pf_crypto_luna="${PF_SERVER_LIB}/pf-crypto-luna.jar"
pf_fips="${SERVER_ROOT_DIR}/lib/bc-fips-1.0.2.jar"

PF_BOOT_CLASSPATH="${PF_BOOT_CLASSPATH}${PF_BOOT_CLASSPATH:+:}${pf_console_util}:${xmlbeans}:${pf_xml}:${pf_crypto_luna}:${pf_fips}"

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
    -classpath "${PF_CLASSPATH}" \
    org.pingidentity.RunPF "${@}"
