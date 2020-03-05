#!/usr/bin/env sh
set -x
_osID=$( awk '$0~/^ID=/ {split($1,id,"="); gsub(/"/,"",id[2]); print id[2];}' </etc/os-release 2>/dev/null )
if test "${1}" = "--experimental" ; then
    JDK_TAR="https://download.java.net/java/early_access/jdk15/8/GPL/openjdk-15-ea+8_linux-x64_bin.tar.gz"
    # experimental mode gets an early access Java build
    JDK_HOME=/jdk
    case "${_osID}" in
        ubuntu|debian)
            apt-get -y update
        ;;
        centos)
            yum update -y
        ;;
        alpine)
            apk add curl
            JDK_TAR="https://download.java.net/java/early_access/alpine/7/binaries/openjdk-15-ea+7_linux-x64-musl_bin.tar.gz"
        ;;
    esac
    curl -o /tmp/jdk.tgz ${JDK_TAR}
    actual_signature=$( sha256sum /tmp/jdk.tgz | awk '{print $1}' )
    expected_signature=$( curl ${JDK_TAR}.sha256 )
    if test "${actual_signature}" = "${expected_signature}" ; then
        tar xzf /tmp/jdk.tgz
        mv jdk-* jdk
        rm -f /tmp/jdk.tgz
    fi
    JDK_HOME=/tmp/jdk
else
    case "${_osID}" in
        ubuntu|debian)
            if type ${JAVA_HOME}/bin/jlink >/dev/null 2>/dev/null ;
            then
            ${JAVA_HOME}/bin/jlink \
                --compress=2 \
                --no-header-files \
                --no-man-pages \
                --module-path ${JAVA_HOME}/jmods \
                --add-modules java.base,java.compiler,java.datatransfer,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml.crypto,java.xml,jdk.charsets,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.jdwp.agent,jdk.httpserver,jdk.localedata,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.rmic,jdk.security.auth,jdk.security.jgss,jdk.xml.dom,jdk.zipfs \
                --output /opt/java
            else
                # this seemingly slightly over-complicated strategy to move the jre to /opt/java
                # is necessary because some distros (namely adopt hotspot) have the jre under /opt/java/<something>
                mkdir -p /opt 2>/dev/null
                _java_actual=$( readlink -f ${JAVA_HOME}/bin/java )
                _java_home_actual=$( dirname $( dirname "${_java_actual}" ) )
                mv ${_java_home_actual} /tmp/java
                rm -rf /opt/java
                mv /tmp/java /opt/java
            fi
        ;;
        centos)
            if type ${JAVA_HOME}/bin/jlink >/dev/null 2>/dev/null ;
            then
                ${JAVA_HOME}/bin/jlink \
                    --compress=2 \
                    --no-header-files \
                    --no-man-pages \
                    --module-path ${JAVA_HOME}/jmods \
                    --add-modules java.base,java.compiler,java.datatransfer,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml.crypto,java.xml,jdk.charsets,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.jdwp.agent,jdk.httpserver,jdk.localedata,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.rmic,jdk.security.auth,jdk.security.jgss,jdk.xml.dom,jdk.zipfs \
                    --output /opt/java
            else
                # this seemingly slightly over-complicated strategy to move the jre to /opt/java
                # is necessary because some distros (namely adopt hotspot) have the jre under /opt/java/<something>
                mkdir -p /opt 2>/dev/null
                _java_actual=$( readlink -f ${JAVA_HOME}/bin/java )
                _java_home_actual=$( dirname $( dirname "${_java_actual}" ) )
                mv ${_java_home_actual} /tmp/java
                rm -rf /opt/java
                mv /tmp/java /opt/java
            fi
        ;;
        alpine)
            if type ${JAVA_HOME}/bin/jlink >/dev/null 2>/dev/null ;
            then
                ${JAVA_HOME}/bin/jlink \
                    --compress=2 \
                    --no-header-files \
                    --no-man-pages \
                    --module-path ${JAVA_HOME}/jmods \
                    --add-modules java.base,java.compiler,java.datatransfer,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml.crypto,java.xml,org.openjsse,jdk.charsets,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.jdwp.agent,jdk.httpserver,jdk.localedata,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.rmic,jdk.security.auth,jdk.security.jgss,jdk.xml.dom,jdk.zipfs \
                    --output /opt/java
            else
                # this seemingly slightly over-complicated strategy to move the jre to /opt/java
                # is necessary because some distros (namely adopt hotspot) have the jre under /opt/java/<something>
                mkdir -p /opt 2>/dev/null
                _java_actual=$( readlink -f ${JAVA_HOME}/bin/java )
                _java_home_actual=$( dirname $( dirname "${_java_actual}" ) )
                mv ${_java_home_actual} /tmp/java
                rm -rf /opt/java
                mv /tmp/java /opt/java
            fi
            ;;
    esac
fi
rm ${0}