#!/usr/bin/env sh
set -e
DIRNAME=$( dirname "${0}" )

# Setup the JVM
if test "${JAVA}" = "" ;
then
    if test "${JAVA_HOME}" != "" ; 
    then
        JAVA="${JAVA_HOME}/bin/java"
    else
        JAVA="java"
        echo "JAVA_HOME is not set.  Unexpected results may occur."
        echo "Set JAVA_HOME environment variable to the location of your Java installation to avoid this message."
    fi
fi

# Check for sufficient JVM version
if test "${JVM_VERSION}" = "" ;
then
    JAVA_MAJOR_VERSION=$( "${JAVA}" -version 2>&1 | awk '$0~ /version/ {gsub(/"/,"",$3);gsub(/\..*/,"",$3);gsub(/-.*/,"",$3);print $3;}' )
    if test "${JAVA_MAJOR_VERSION}" -lt "11" ;
    then
        echo "This utility must be run using Java 11 or higher. Exiting."
        exit 1
    fi
fi

PINGCENTRAL_HOME=$( cd "${DIRNAME}/.."; pwd )
CONFIG="${PINGCENTRAL_HOME}/conf"
LOG="${PINGCENTRAL_HOME}/log"
LOG4J2_PROPS="${CONFIG}/log4j2.xml"
cd "${PINGCENTRAL_HOME}"
java -jar \
    -Dlogging.config="${LOG4J2_PROPS}" \
    -Dspring.config.additional-location="file:${CONFIG}/" \
    -Dpingcentral.jwk="${CONFIG}/pingcentral.jwk" \
    -Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager \
    -Dlog4j2.AsyncQueueFullPolicy=Discard \
    -Dlog4j2.enable.threadlocals=false \
    -Dlog4j2.DiscardThreshold=INFO \
    -Dpath.applogger.prop="${LOG}/application.log" \
    -Dpath.apilogger.prop="${LOG}/application-api.log" \
    -Dpath.extlogger.prop="${LOG}/application-ext.log"  \
    -Dpath.monitorlogger.prop="${LOG}/monitor.log" \
    -Djava.security.egd=file:/dev/./urandom \
    -Dloader.path="${PINGCENTRAL_HOME}/ext-lib" \
    ping-central.jar "${@}"
