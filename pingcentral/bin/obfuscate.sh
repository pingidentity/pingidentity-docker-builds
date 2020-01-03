#!/bin/sh
set -e
DIRNAME=`dirname $0`
PROGNAME=`basename $0`

# Setup the JVM
if [ "$JAVA" = "" ]; then
    if [ "$JAVA_HOME" != "" ]; then
        JAVA="$JAVA_HOME/bin/java"
    else
        JAVA="java"
        echo "JAVA_HOME is not set.  Unexpected results may occur."
        echo "Set JAVA_HOME environment variable to the location of your Java installation to avoid this message."
    fi
fi

# Check for sufficient JVM version
if [ "$JVM_VERSION" = "" ]; then
    JAVA_FULL_VERSION=`"$JAVA" -version 2>&1 | head -1 | cut -d '"' -f2`
    JAVA_BASE_VERSION=`/bin/echo ${JAVA_FULL_VERSION} | cut -d "." -f1`
    if [ "$JAVA_BASE_VERSION" -lt "11" ]; then
        /bin/echo "This utility must be run using Java 11 or higher. Exiting."
        exit 1
    fi
fi

PINGCENTRAL_HOME=`cd $DIRNAME/..; pwd`
cd "$PINGCENTRAL_HOME"

if [[ $1 = "--help" || $1 = "-help" || $1 = "-h" ]]
then
    echo
    echo 'Usage:' $PROGNAME '[PASSWORD]'
    echo
    echo 'Prompts for a password, encrypts/encodes it, then prints the result.'
    echo 'To avoid prompting, a PASSWORD argument may be specified. However, this is generally less secure.'
    echo
    exit 1
fi

"$JAVA" -Dloader.main=com.pingidentity.pass.cli.PasswordEncoder -jar ping-central.jar "$@"

