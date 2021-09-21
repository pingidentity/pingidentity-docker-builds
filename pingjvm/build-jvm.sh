#!/usr/bin/env sh
test "${VERBOSE}" = "true" && set -x

_osID=$(awk '$0~/^ID=/ {split($1,id,"="); gsub(/"/,"",id[2]); print id[2];}' < /etc/os-release 2> /dev/null)
_osArch=$(uname -m)

if ! type java > /dev/null 2> /dev/null; then
    # there is no Java, we'll pull down Liberica

    # optimized modules java 11 alpine modules
    # on liberica, no org.openjsse (which delivers TLS 1.3 for java 8 actually so that makes sense)
    # _modules="java.base,java.compiler,java.datatransfer,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml.crypto,java.xml,jdk.charsets,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.jdwp.agent,jdk.httpserver,jdk.jcmd,jdk.localedata,jdk.management,jdk.management.agent,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.rmic,jdk.security.auth,jdk.security.jgss,jdk.unsupported,jdk.xml.dom,jdk.zipfs"
    _jdkDir="$(mktemp -d)"
    _jdkArchive="${_jdkDir}/jdk.tgz"
    JDK_VERSION="11.0.12+7"
    if test "aarch64" = "${_osArch}"; then
        _arch="${_osArch}"
        _digest="5633780b728140cc16d73b0a2b6165f4a19afc4f"
    else
        # on Intel
        _arch="x64"
        _digest="3ecb384285975e73b841f8cfe829e3cf5aac27ba"
    fi
    case "${_osID}" in
        alpine)
            _libc="-musl"
            _cmd="wget -O"
            ;;
        rhel)
            curl -o busybox https://busybox.net/downloads/binaries/1.31.0-i686-uclibc/busybox
            chmod +x busybox
            _cmd="curl -o"
            _libc=""
            _arch="amd64"
            _digest="25095da274b159f4233a2b69eb4aea1dbd099e9b"
            ;;
    esac
    _jdkURL="https://download.bell-sw.com/java/${JDK_VERSION}/bellsoft-jdk${JDK_VERSION}-linux-${_arch}${_libc}.tar.gz"
    eval "${_cmd}" "${_jdkArchive}" "${_jdkURL}"
    test "${_digest}" = "$(sha1sum "${_jdkArchive}" | awk '{print $1}')" || exit 95
    ! type tar > /dev/null 2>&1 && _prefix="./busybox"
    ${_prefix} tar -C "${_jdkDir}" -xzf "${_jdkArchive}"
    rm "${_jdkArchive}"
    JAVA_HOME="$(find "${_jdkDir}" -type d -name jdk-\*)"
    export JAVA_HOME
    export PATH="${JAVA_HOME}/bin:${PATH}"
fi

_javaMajor=$("${JAVA_HOME}"/bin/java -version 2>&1 | awk '$0~ /version/ {gsub(/"/,"",$3);gsub(/\..*/,"",$3);gsub(/-.*/,"",$3);print $3;}')
_javaImplementor="$(awk -F= '$1~/IMPLEMENTOR/{gsub(/"/,"",$2);print $2}' "${JAVA_HOME}/release")"
MODULES_PATH="${JAVA_HOME}/jmods"
if type "${JAVA_HOME}/bin/jlink" > /dev/null 2> /dev/null; then
    if test -d "${MODULES_PATH}"; then
        # _modules=""
        case "${_osID}" in
            ubuntu | debian) ;;

            centos | amzn)
                case "${_javaMajor}" in
                    11)
                        if test -z "${_modules}"; then
                            echo "Optimizing module list for Java 11 LTS"
                            # if the modules haven't been set for liberica earlier, then set the modules for corretto
                            # no org.openjsse on corretto
                            _modules="java.base,java.compiler,java.datatransfer,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml.crypto,java.xml,jdk.charsets,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.jdi,jdk.jdwp.agent,jdk.httpserver,jdk.jcmd,jdk.localedata,jdk.management,jdk.management.agent,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.rmic,jdk.security.auth,jdk.security.jgss,jdk.xml.dom,jdk.zipfs"
                        fi
                        ;;
                    *)
                        echo "The list of modules is only optimized for Java 11 LTS currently"
                        ;;
                esac
                ;;
            alpine)
                case "${_javaMajor}" in
                    11)
                        if test -z "${_modules}"; then
                            echo "Optimizing module list for ${_javaImplementor} Java 11 LTS"
                            case "${_javaImplementor}" in
                                BellSoft)
                                    # _modules="java.base,java.compiler,java.datatransfer,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml.crypto,java.xml,jdk.charsets,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.jdwp.agent,jdk.httpserver,jdk.jcmd,jdk.localedata,jdk.management,jdk.management.agent,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.rmic,jdk.security.auth,jdk.security.jgss,jdk.unsupported,jdk.xml.dom,jdk.zipfs"
                                    ;;
                                *)
                                    # if the modules haven't been set for liberica earlier, then set the modules for zulu
                                    #  including org.openjsse works on zulu for some reason
                                    # exclude jdk.unsupported
                                    echo "Optimizing module list for ${_javaImplementor} Java 11 LTS"
                                    _modules="java.base,java.compiler,java.datatransfer,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml.crypto,java.xml,org.openjsse,jdk.charsets,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.jdi,jdk.jdwp.agent,jdk.httpserver,jdk.jcmd,jdk.localedata,jdk.management,jdk.management.agent,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.rmic,jdk.security.auth,jdk.security.jgss,jdk.xml.dom,jdk.zipfs"
                                    ;;
                            esac
                        fi
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
        if test -z "${_modules}"; then
            for i in "${JAVA_HOME}/jmods"/*.jmod; do
                _modules="${_modules:+${_modules},}$(basename "${i%.jmod}")"
            done
        fi
        JAVA_BUILD_DIR="/opt/java"
        "${JAVA_HOME}/bin/java" -version
        test ${?} -ne 0 && exit 97
        # Word-split is expected behavior for $_modules. Disable shellcheck.
        # shellcheck disable=SC2086
        "${JAVA_HOME}/bin/jlink" \
            --compress=2 \
            --no-header-files \
            --no-man-pages \
            --verbose \
            --strip-debug \
            --module-path "${JAVA_HOME}/jmods" \
            --add-modules ${_modules} \
            --output "${JAVA_BUILD_DIR}"
        test ${?} -ne 0 && exit 99
        test -n "${_jdkDir}" && test -d "${_jdkDir}" && rm -rf "${_jdkDir}"
        ! test -d "${JAVA_BUILD_DIR}" && exit 98
        # verify we produced a viable jvm
        "${JAVA_BUILD_DIR}/bin/java" -version
        test ${?} -ne 0 && exit 96
    else
        cp -rf "${JAVA_HOME}" /opt/java
    fi
else
    # this seemingly slightly over-complicated strategy to move the jre to /opt/java
    # is necessary because some distros (namely adopt hotspot) have the jre under /opt/java/<something>
    mkdir -p /opt 2> /dev/null
    _java_actual=$(readlink -f "${JAVA_HOME}/bin/java")
    _java_home_actual=$(dirname "$(dirname "${_java_actual}")")
    mv "${_java_home_actual}" /tmp/java
    rm -rf /opt/java
    mv /tmp/java /opt/java
fi

/opt/java/bin/java -version 2>&1 | tee > /opt/java/_version

rm "${0}"
exit 0
