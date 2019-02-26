#!/usr/bin/env sh


DIRNAME=$( dirname "$0" )
PROGNAME=$( basename "$0" )

#
# helper to abort.
#
die() {
    (>&2 echo "$*")
    exit 1
}

#
# Helper to complain.
#
warn() {
    echo "${PROGNAME}: $*"
}


# OS specific support (must be 'true' or 'false').
darwin=false;
case "$( uname )" in
    Darwin*)
        darwin=true
        ;;
esac

# Increase the maximum file descriptors if we can
# Use the maximum available, or set MAX_FD != -1 to use that
MAX_FD="maximum"

MAX_FD_LIMIT=$( ulimit -H -n )
if test ${?} -eq 0 ; then
    if test "${MAX_FD}" = "maximum" || "${MAX_FD}" = "max" ; then
        # use the system max
        MAX_FD="${MAX_FD_LIMIT}"
    fi

    if test "$darwin" = "false" ; then
        ulimit -n "${MAX_FD}"
        if [ ${?} -ne 0 ]; then
            warn "Could not set maximum file descriptor limit: ${MAX_FD}"
        fi
    fi
else
    warn "Could not query system maximum file descriptor limit: ${MAX_FD_LIMIT}"
fi

# Setup the JVM
if test "${JAVA}" = "" ; then
    if test "${JAVA_HOME}" != "" ; then
        JAVA="${JAVA_HOME}/bin/java"
    else
        JAVA="java"
        echo "JAVA_HOME is not set.  Unexpected results may occur."
        echo "Set JAVA_HOME environment variable to the location of your Java installation to avoid this message."
    fi
fi

# Ensure that Java is accessible
JAVA_VERSION_OUTPUT=$( "${JAVA}" -version 2>&1 )
if [ ${?} -ne 0 ]; then
    echo "${JAVA_VERSION_OUTPUT}"
    die "Error running Java: ${JAVA}"
fi

#
# Obtain and evaluate Java version string by executing the java command. Java 8 starts with "1.8", while both
# Oracle and OpenJDK Java will return the same $FEATURE.$INTERIM.$UPDATE.$PATCH formatted string (JEP 322).
#
JAVA_VERSION_STRING=$( echo "${JAVA_VERSION_OUTPUT}" | head -1 | cut -d '"' -f2 )
javaSupportedVersion=0
javaIsJava8=0

case "${JAVA_VERSION_STRING}" in
    1.8*)            # Java 8
        javaSupportedVersion=1
        javaIsJava8=1
        ;;
    1.*)             # Earlier than Java 8 not supported
        ;;
    9|9.*|10|10.*)   # Pre-LTS Java 9 and 10 not supported
        ;;
    *)               # Java 11 or later
        javaSupportedVersion=1
        ;;
esac

if test ${javaSupportedVersion} -eq 0 ; then
        die "Java version ${JAVA_VERSION_STRING} is not supported for running PingAccess. Exiting."
fi

# Setup PA_HOME
if test "x${PA_HOME}" = "x" ; then
    PA_HOME=$( cd "${DIRNAME}/.."; pwd )
fi
export PA_HOME
PA_HOME_ESC=${PA_HOME// /%20}

runprops="${PA_HOME}/conf/run.properties"
pajwk="${PA_HOME}/conf/pa.jwk"
pajwkprops="${PA_HOME}/conf/pa.jwk.properties"
bootprops="${PA_HOME}/conf/bootstrap.properties"
jvmmemoryopts="${PA_HOME}/conf/jvm-memory.options"

# Check for run.properties (used by PingAccess to configure ports, etc.)
if [ ! -f "${runprops}" ]; then
    warn "Missing run.properties; using defaults."
    runprops=""
fi

# Check for bootstrap.properties (used by PingAccess to configure bootstrapping information for engines)
if [ ! -f "${bootprops}" ]; then
    # warn "Missing bootstrap.properties;"
    bootprops=""
fi

# Check for jvm-memory.options (used by PingAccess to set JVM memory settings)
if [ ! -f "${jvmmemoryopts}" ]; then
    die "Missing ${jvmmemoryopts}"
fi

#Setup JVM Heap optimizations
# JVM_MEMORY_OPTS=
# allDone=false
# until $allDone; do
#     #Read every line. Last line might return a non-zero exit code if not followed by a new line, but still reads the line.
#     read -r line || allDone=true
#     #Filter empty and commented lines
#     ( [[ $line =~ ^#.*$ ]] || [[ -z $line ]] ) && continue
#     JVM_MEMORY_OPTS="$JVM_MEMORY_OPTS $line"
# done < "$jvmmemoryopts"
JVM_MEMORY_OPTS=$( awk 'BEGIN{OPTS=""} $1!~/^#/{OPTS=OPTS" "$0;} END{print}' <${jvmmemoryopts} )

JAVA_8_OPTS="
    -XX:+AggressiveOpts"

POST_JAVA_8_OPTS="
    --add-opens java.base/java.lang.invoke=ALL-UNNAMED
    -Dnet.bytebuddy.experimental=true"

#
# Preparation for Java 8 runtime.
#
if test ${javaIsJava8} -eq 1 ; then

    # If JAVA_OPTS is not set, at least set server JVM
    if test "${JAVA_OPTS}" = "" ; then

        # MacOS does not support -server flag
        if test "${darwin}" != "true" ; then
            JAVA_OPTS="-server"
        fi
    fi

    JAVA_OPTS="${JAVA_OPTS} ${JAVA_8_OPTS}"
else
    JAVA_OPTS="${JAVA_OPTS} ${POST_JAVA_8_OPTS}"
fi

#uncomment to enable DEBUG mode in JVM
#DEBUG="-Xdebug -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n"

CLASSPATH="${PA_HOME}/conf"
CLASSPATH="${CLASSPATH}:${PA_HOME}/lib/*"
export CLASSPATH

LOG4J2_PROPS="${PA_HOME}/conf/log4j2.xml"

#comment out to disable java crash logs
ERROR_FILE="-XX:ErrorFile=${PA_HOME_ESC}/log/java_error%p.log"

#uncomment to enable Memory Dumps
#HEAP_DUMP="-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$PA_HOME_ESC/log"

#
# This setting defines the random source used by PingAccess for cryptographic operations such as TLS or token signing
# and encryption. Using a random source of /dev/./urandom provides significant performance benefits.
#
RANDOM_SOURCE="-Djava.security.egd=file:/dev/./urandom"

JAVA_OPTS="${JAVA_OPTS} ${B4J_LIVE_CONFIG} ${JVM_MEMORY_OPTS} ${DEBUG} ${ERROR_FILE} ${HEAP_DUMP} ${RANDOM_SOURCE}"

cd "$PA_HOME"
"${JAVA}" -classpath "${CLASSPATH}" ${JAVA_OPTS} \
    -Djavax.net.ssl.sessionCacheSize=5000 \
    -Djava.net.preferIPv4Stack=true \
    -Djava.net.preferIPv6Addresses=false \
    -Djava.awt.headless=true \
    -Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager\
    -Dpa.jwk="${pajwk}" \
    -Dpa.jwk.properties="${pajwkprops}" \
    -Dlog4j.configurationFile="${LOG4J2_PROPS}" \
    -Dlog4j2.AsyncQueueFullPolicy=Discard \
    -Dlog4j2.enable.threadlocals=false \
    -Dlog4j2.DiscardThreshold=INFO \
    -Dhibernate.cache.ehcache.missing_cache_strategy=create \
    -Drun.properties="${runprops}" \
    -Dbootstrap.properties="${bootprops}" \
    -Dpa.home="${PA_HOME}" \
    com.pingidentity.pa.cli.Starter "$@"
