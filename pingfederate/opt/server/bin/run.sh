#!/usr/bin/env sh
### ====================================================================== ###
##                                                                          ##
##  PingFederate Docker Bootstrap Script                                    ##
##                                                                          ##
### ====================================================================== ###
test "${VERBOSE}" = "true" && set -x
DIRNAME=$(dirname "${0}")
PROGNAME=$(basename "${0}")
GREP="grep"

# Use the maximum available, or set MAX_FD != -1 to use that
MAX_FD="maximum"

#
# Helper to complain.
#
warn () 
{
    echo "${PROGNAME}: ${*}"
}

#
# Helper to fail.
#
die () 
{
    warn "${@}"
    exit 1
}

#
# Helper to check required files
#
require ()
{
    _requiredFile=${1}
    shift
    if ! test -f "${_requiredFile}"
    then
        die "Missing required file: ${_requiredFile}"
    fi
}

# Read an optional running configuration file
if test -z "${RUN_CONF}"
then
    RUN_CONF="${DIRNAME}/run.conf"
fi
if test -r "${RUN_CONF}"
then
    # shellcheck disable=SC1090
    . "${RUN_CONF}"
fi

# Setup PF_HOME
if test -z "${PF_HOME}"
then
    # get the full path (without any relative bits)
    PF_HOME=$( cd "${DIRNAME}/.."||exit 99; pwd )
fi
export PF_HOME
PF_BIN="${PF_HOME}/bin"
PF_SERVER_HOME="${PF_HOME}/server/default"
PF_SERVER_LIB="${PF_SERVER_HOME}/lib"

# Set PF_HOME_ESC - this is PF_HOME but with spaces that are replaced with %20
# PF_HOME_ESC=${PF_HOME// /%20}
PF_HOME_ESC=$( echo "${PF_HOME}" | awk '{gsub(/ /,"%20");print;}' )

# Check for currently running instance of PingFederate
RUNFILE="${PF_BIN}/pingfederate.pid"
if test ! -f "${RUNFILE}"
then
  touch "${RUNFILE}"
  chmod 664 "${RUNFILE}"
fi

CURRENT_PID=$(cat "${RUNFILE}")
if test -n "${CURRENT_PID}"
then
    kill -0 "${CURRENT_PID}" 2>/dev/null
    if test ${?} -eq 0 ; then
      /bin/echo "Another PingFederate instance with pid ${CURRENT_PID} is already running. Exiting."
      exit 1
    fi
fi

MAX_FD_LIMIT=$(ulimit -H -n)
if test ${?} -eq 0
then
    if test "${MAX_FD}" = "maximum" -o "${MAX_FD}" = "max"
    then
        # use the system max
        MAX_FD="${MAX_FD_LIMIT}"
    fi

    ulimit -n ${MAX_FD}
    if test ${?} -ne 0
    then
            warn "Could not set maximum file descriptor limit: ${MAX_FD}"
    fi
else
    warn "Could not query system maximum file descriptor limit: ${MAX_FD_LIMIT}"
fi

# Setup the JVM
if test -z "${JAVA}"
then
    if test -n "${JAVA_HOME}"
    then
        if test -z "${JAVA_HOME}" || ! test -x "${JAVA_HOME}/bin/java"
        then
            echo "No executable java found in JAVA_HOME, please correct and start PingFederate again. Exiting."
            exit 1
        fi
        JAVA="${JAVA_HOME}/bin/java"
    else
        JAVA="java"
        warn "JAVA_HOME is not set.  Unexpected results may occur."
        warn "Set JAVA_HOME to the directory of your local JDK or JRE to avoid this message."
    fi
fi

JAVA_MAJOR_VERSION=$( "${JAVA}" -version 2>&1 | awk '$0~ /version/ {gsub(/"/,"",$3);gsub(/\..*/,"",$3);print $3;}' )

# Setup the classpath
runjar="${PF_BIN}/run.jar"
pfrunjar="${PF_BIN}/pf-startup.jar"
jettystartjar="${PF_BIN}/jetty-start.jar"
xmlbeans="${PF_SERVER_LIB}/xmlbeans.jar"
pfxml="${PF_SERVER_LIB}/pf-xml.jar"
PF_BOOT_CLASSPATH=""
for requiredFile in ${runjar} ${pfrunjar} ${jettystartjar} ${xmlbeans} ${pfxml}
do
    require ${requiredFile}
    PF_BOOT_CLASSPATH="${PF_BOOT_CLASSPATH}${PF_BOOT_CLASSPATH:+:}${requiredFile}"
done


pf_console_util="${PF_BIN}/pf-consoleutils.jar"
pf_crypto_luna="${PF_SERVER_LIB}/pf-crypto-luna.jar"
pf_fips="${PF_HOME}/lib/bc-fips-1.0.2.jar"

PF_BOOT_CLASSPATH="${PF_BOOT_CLASSPATH}${PF_BOOT_CLASSPATH:+:}${pf_console_util}:${xmlbeans}:${pfxml}:${pf_crypto_luna}:${pf_fips}"

PF_CLASSPATH="${PF_CLASSPATH}${PF_CLASSPATH:+:}${PF_BOOT_CLASSPATH}"

# If JAVA_OPTS is not set try check for Hotspot
HAS_HOTSPOT=$( ${JAVA} -version 2>&1 | ${GREP} -i HotSpot )
if test -z "${JAVA_OPTS}" && test -n "${HAS_HOTSPOT}"
then
    JAVA_OPTS="-server"
fi

jvmmemoryopts="${PF_BIN}/jvm-memory.options"
require ${jvmmemoryopts}
JVM_MEMORY_OPTS=$( awk 'BEGIN{OPTS=""} $1!~/^#/{OPTS=OPTS" "$0;} END{print OPTS}' <"${jvmmemoryopts}" )

JAVA_OPTS="${JAVA_OPTS} ${JVM_MEMORY_OPTS}"

# Setup PingFederate specific properties
JAVA_OPTS="${JAVA_OPTS} -Dprogram.name=${PROGNAME}"

RANDOM_SOURCE="-Djava.security.egd=file:/dev/./urandom"
JAVA_OPTS="${JAVA_OPTS} ${RANDOM_SOURCE}"

# Workaround for nCipher HSM to support Java 8
# Remove this when nCipher officially supports Java 8
JAVA_OPTS="${JAVA_OPTS} -Dcom.ncipher.provider.announcemode=on"

# JAVA_OPTS="-Djetty51.encode.cookies=CookieName1,CookieName2 $JAVA_OPTS"

# Debugger arguments
if test "${PF_ENGINE_DEBUG}" = "true" || test "${PF_ADMIN_DEBUG}" = "true"
then
    JAVA_OPTS="-Xdebug -Xrunjdwp:transport=dt_socket,address=${PF_DEBUG_PORT},server=y,suspend=n $JAVA_OPTS"
fi

# disable use of preallocated exceptions and always show the full stacktrace
JAVA_OPTS="${JAVA_OPTS} -XX:-OmitStackTraceInFastThrow"

# Setup the java endorsed dirs
PF_ENDORSED_DIRS="${PF_HOME}/lib/endorsed"

#comment out to disable java crash logs
ERROR_FILE="-XX:ErrorFile=${PF_HOME_ESC}/log/java_error%p.log"

#uncomment to enable Memory Dumps
#HEAP_DUMP="-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$PF_HOME_ESC/log"

ENDORSED_DIRS_FLAG=""
if test "${JAVA_MAJOR_VERSION}" = "1"
then
    # shellcheck disable=SC2089
    ENDORSED_DIRS_FLAG="-Djava.endorsed.dirs=\"${PF_ENDORSED_DIRS}\""
fi

# Check for run.properties (used by PingFederate to configure ports, etc.)
runprops="${PF_BIN}/run.properties"
if ! test -f "${runprops}"
then
    warn "Missing run.properties; using defaults."
    runprops=""
fi

function getProperty {
    if [ -f "${runprops}" ]; then
        PROP_KEY=$1
        PROP_VALUE=`cat "${runprops}" | grep "${PROP_KEY}" | cut -d'=' -f2`
        echo ${PROP_VALUE}
        return 0
    else
        echo true
        return 0
    fi
}
APPROVED_ONLY=$( getProperty "org.bouncycastle.fips.approved_only" )

# Only use FIPS approved methods if the Bouncy Castle FIPS module is used
JAVA_OPTS="${JAVA_OPTS} -Dorg.bouncycastle.fips.approved_only=${APPROVED_ONLY}"

trap 'kill ${PID}; wait ${PID}; cat </dev/null 2>/dev/null >${RUNFILE}' 1 2 3 6
trap 'kill -9 ${PID}; cat </dev/null >${RUNFILE} 2>/dev/null' 15

STATUS=10
while test ${STATUS} -eq 10
do
    # Execute the JVM
    # shellcheck disable=SC2086,SC2090
    "${JAVA}" ${JAVA_OPTS} \
        ${ERROR_FILE} \
        ${HEAP_DUMP} \
        ${ENDORSED_DIRS_FLAG} \
        -Dlog4j2.AsyncQueueFullPolicy=Discard \
        -Dlog4j2.DiscardThreshold=INFO \
        -Dlog4j.configurationFile="${PF_HOME_ESC}/server/default/conf/log4j2.xml" \
        -Drun.properties="${runprops}" \
        -Dpf.home="${PF_HOME}" \
        -Djetty.home="${PF_HOME}" \
        -Djetty.base="${PF_BIN}" \
        -Djetty.server=com.pingidentity.appserver.jetty.PingFederateInit \
        -Dpf.server.default.dir="${PF_SERVER_HOME}" \
        -Dpf.java="${JAVA}" \
        -Dpf.java.opts="${JAVA_OPTS} -Drun.properties=${runprops}" \
        -Dpf.classpath="${PF_CLASSPATH}" \
        -classpath "${PF_CLASSPATH}" \
        org.pingidentity.RunPF "$@" &
   PID=${!}
   /bin/echo ${PID} 2>/dev/null >"${RUNFILE}"
   wait ${PID}
   STATUS=${?}

   cat </dev/null 2>/dev/null >"${RUNFILE}"
done