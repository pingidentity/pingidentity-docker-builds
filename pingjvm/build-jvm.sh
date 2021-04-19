#!/usr/bin/env sh
test -n "${VERBOSE}" && set -x

_osID=$( awk '$0~/^ID=/ {split($1,id,"="); gsub(/"/,"",id[2]); print id[2];}' </etc/os-release 2>/dev/null )
_javaMajor=$( "${JAVA_HOME}"/bin/java -version 2>&1 | awk '$0~ /version/ {gsub(/"/,"",$3);gsub(/\..*/,"",$3);gsub(/-.*/,"",$3);print $3;}' )

if type ${JAVA_HOME}/bin/jlink >/dev/null 2>/dev/null ;
then
    _modules=""
    case "${_osID}" in
        ubuntu|debian)
        ;;
        centos)
        ;;
        alpine)
            case "${_javaMajor}" in
                11)
                    # optimized modules azul 11 alpine modules
                    _modules="java.base,java.compiler,java.datatransfer,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml.crypto,java.xml,org.openjsse,jdk.charsets,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.jdwp.agent,jdk.httpserver,jdk.jcmd,jdk.jdi,jdk.localedata,jdk.management,jdk.management.agent,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.rmic,jdk.security.auth,jdk.security.jgss,jdk.xml.dom,jdk.zipfs"
                ;;
                *)
                    # all azul modules
                    # --add-modules java.base,java.compiler,java.datatransfer,java.desktop,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml.crypto,java.xml,jdk.accessibility,jdk.aot,jdk.attach,jdk.charsets,jdk.compiler,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.dynalink,jdk.editpad,jdk.hotspot.agent,jdk.httpserver,jdk.internal.ed,jdk.internal.jvmstat,jdk.internal.le,jdk.internal.opt,jdk.internal.vm.ci,jdk.internal.vm.compiler,jdk.internal.vm.compiler.management,jdk.jartool,jdk.javadoc,jdk.jcmd,jdk.jconsole,jdk.jdeps,jdk.jdi,jdk.jdwp.agent,jdk.jfr,jdk.jlink,jdk.jshell,jdk.jsobject,jdk.jstatd,jdk.localedata,jdk.management.agent,jdk.management.jfr,jdk.management,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.pack,jdk.rmic,jdk.scripting.nashorn,jdk.scripting.nashorn.shell,jdk.sctp,jdk.security.auth,jdk.security.jgss,jdk.unsupported.desktop,jdk.unsupported,jdk.xml.dom,jdk.zipfs,org.openjsse \
                    # all openjdk 11 modules
                    # --add-modules java.base,java.compiler,java.datatransfer,java.desktop,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml.crypto,java.xml,jdk.accessibility,jdk.aot,jdk.attach,jdk.charsets,jdk.compiler,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.dynalink,jdk.editpad,jdk.hotspot.agent,jdk.httpserver,jdk.internal.ed,jdk.internal.jvmstat,jdk.internal.le,jdk.internal.opt,jdk.internal.vm.ci,jdk.internal.vm.compiler,jdk.internal.vm.compiler.management,jdk.jartool,jdk.javadoc,jdk.jcmd,jdk.jconsole,jdk.jdeps,jdk.jdi,jdk.jdwp.agent,jdk.jfr,jdk.jlink,jdk.jshell,jdk.jsobject,jdk.jstatd,jdk.localedata,jdk.management.agent,jdk.management.jfr,jdk.management,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.pack,jdk.rmic,jdk.scripting.nashorn,jdk.scripting.nashorn.shell,jdk.sctp,jdk.security.auth,jdk.security.jgss,jdk.unsupported.desktop,jdk.unsupported,jdk.xml.dom,jdk.zipfs \
                    # all openjdk 15 modules
                    # --add-modules java.base,java.compiler,java.datatransfer,java.desktop,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml.crypto,java.xml,jdk.accessibility,jdk.aot,jdk.attach,jdk.charsets,jdk.compiler,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.dynalink,jdk.editpad,jdk.hotspot.agent,jdk.httpserver,jdk.incubator.foreign,jdk.incubator.jpackage,jdk.internal.ed,jdk.internal.jvmstat,jdk.internal.le,jdk.internal.opt,jdk.internal.vm.ci,jdk.internal.vm.compiler,jdk.internal.vm.compiler.management,jdk.jartool,jdk.javadoc,jdk.jcmd,jdk.jconsole,jdk.jdeps,jdk.jdi,jdk.jdwp.agent,jdk.jfr,jdk.jlink,jdk.jshell,jdk.jsobject,jdk.jstatd,jdk.localedata,jdk.management.agent,jdk.management.jfr,jdk.management,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.nio.mapmode,jdk.rmic,jdk.scripting.nashorn,jdk.scripting.nashorn.shell,jdk.sctp,jdk.security.auth,jdk.security.jgss,jdk.unsupported.desktop,jdk.unsupported,jdk.xml.dom,jdk.zipfs \
                ;;
            esac
        ;;
    esac
    # build the list of all modules.
    # worst case scenario, when moving to a new JDK with different modules we haven't had time to prune
    if test -z "${_modules}" ;
    then
        for i in ${JAVA_HOME}/jmods/*.jmod ;
        do
            _modules="${_modules:+${_modules},}$( basename ${i%.jmod} )"
        done
    fi
    "${JAVA_HOME}/bin/jlink" \
        --compress=2 \
        --no-header-files \
        --no-man-pages \
        --module-path "${JAVA_HOME}/jmods" \
        --add-modules ${_modules} \
        --output /opt/java
else
    # this seemingly slightly over-complicated strategy to move the jre to /opt/java
    # is necessary because some distros (namely adopt hotspot) have the jre under /opt/java/<something>
    mkdir -p /opt 2>/dev/null
    _java_actual=$( readlink -f ${JAVA_HOME}/bin/java )
    _java_home_actual=$( dirname "$( dirname "${_java_actual}" )" )
    mv "${_java_home_actual}" /tmp/java
    rm -rf /opt/java
    mv /tmp/java /opt/java
fi

_java_security_path=/opt/java/conf/security

# ensure the java.security file exists
if test -f ${_java_security_path}/java.security ;
then
# search the file to add the "security.provider.4=org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider"
# after the listed JSSE provider.
# Renumber the supported security providers.
    awk '{
        for(i=1;i<=NF;i++)
        {
            if($i~/security.provider.([1-9]|[1][1-9])=/)
            {
                if($i~/SunJSSE/)
                {
                    b=1
                    print"security.provider.4=org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider"
                    sub(/[1-9]/, substr($i, index($i,"=")-1)+1)
                    print
                    next
                }

                if(b>0)
                {
                    sub(/[1-9]|[1-9][0-9]/, substr($i, length("security.provider.")+1)+1)
                    b++
                }
            }
        }
    } 1' ${_java_security_path}/java.security > ${_java_security_path}/java.security.bcfips
    mv ${_java_security_path}/java.security.bcfips ${_java_security_path}/java.security

    if test -f ${_java_security_path}/openjsse.security ;
    then
        _index=$( awk '/security.provider.([1-9]|[1][1-9])=SunJSSE/{
            print substr($1, length("security.provider.")+1, index($1,"=") - length("security.provider.")-1)
            }' ${_java_security_path}/java.security )

        awk '/=org.openjsse.net.ssl.OpenJSSE/{ gsub(/[1-9]|[1-9][0-9]/, "'${_index}'") } 1' ${_java_security_path}/openjsse.security > ${_java_security_path}/openjsse.security.bcfips
        mv ${_java_security_path}/openjsse.security.bcfips ${_java_security_path}/openjsse.security

    fi

fi

rm ${0}
exit 0