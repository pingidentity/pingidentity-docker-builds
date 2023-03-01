#!/usr/bin/env sh
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License, Version 1.0 only
# (the "License").  You may not use this file except in compliance
# with the License.
#
# You can obtain a copy of the license at
# trunk/ds/resource/legal-notices/cddl.txt
# or http://www.opensource.org/licenses/cddl1.php.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at
# trunk/ds/resource/legal-notices/cddl.txt.  If applicable,
# add the following below this CDDL HEADER, with the fields enclosed
# by brackets "[]" replaced with your own identifying information:
#      Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#
#
#      Portions Copyright 2008-2023 Ping Identity Corporation
#      Portions Copyright 2008 Sun Microsystems, Inc.

#
# function that sets the java home
#
set_java_home_and_args() {
    PRIVATE_UNBOUNDID_JAVA_BIN="${JAVA_HOME}/bin/java"
    PRIVATE_UNBOUNDID_JAVA_HOME="${JAVA_HOME}"
    PRIVATE_UNBOUNDID_JAVA_ARGS=${UNBOUNDID_JAVA_ARGS}
    export PRIVATE_UNBOUNDID_JAVA_BIN PRIVATE_UNBOUNDID_JAVA_HOME PRIVATE_UNBOUNDID_JAVA_ARGS
    if test "$(uname -m)" = "aarch64"; then
        PRIVATE_UNBOUNDID_JAVA_ARGS="${PRIVATE_UNBOUNDID_JAVA_ARGS} -Djdk.lang.Process.launchMechanism=POSIX_SPAWN"
    fi
    if test -f "${INSTANCE_ROOT}/lib/set-java-home"; then

        # Check set-java-home for CRLF
        # Exit if found
        test_crlf "${INSTANCE_ROOT}/lib/set-java-home"
        die_on_error 11 ""

        # cannot follow dynamically generated file
        # shellcheck disable=SC1091
        . "${INSTANCE_ROOT}/lib/set-java-home"
    fi

    if test "${UNBOUNDID_TESTING}" = "true"; then
        PRIVATE_UNBOUNDID_JAVA_ARGS="${PRIVATE_UNBOUNDID_JAVA_ARGS} ${UNBOUNDID_NOVERIFY_ARG}"
        export PRIVATE_UNBOUNDID_JAVA_ARGS
    fi
}

# Determine whether the detected Java environment is acceptable for use.
test_java() {
    if test -z "${PRIVATE_UNBOUNDID_JAVA_ARGS}"; then
        OUTPUT=$("${PRIVATE_UNBOUNDID_JAVA_BIN}" com.unboundid.directory.server.tools.InstallDS -t 2>&1 > /dev/null)
        RESULT_CODE=${?}
        if test ${RESULT_CODE} -eq 13; then
            # This is a particular error code that means that the Java version is
            # not supported.  Let InstallDS to display the localized error message
            echo "${OUTPUT}"
            exit 1
        elif test ${RESULT_CODE} -ne 0; then
            echo "ERROR:  The detected Java version could not be used."
            echo "${OUTPUT}"
            echo "  "
            echo "The detected java binary is:"
            echo "${PRIVATE_UNBOUNDID_JAVA_BIN}"
            echo "You must specify the path to a valid Java installation"
            echo "and use a valid set of JVM arguments."
            if test "${SCRIPT_NAME}" != "setup"; then
                echo "  "
                echo "To change the JVM that is used:"
                echo "1. Edit the default.java-home property defined in"
                echo "${INSTANCE_ROOT}/config/java.properties to reference the new JVM."
                echo "2. Run the command-line ${INSTANCE_ROOT}/bin/dsjavaproperties"
            fi
            exit 1
        fi
    else
        # the variable PRIVATE_UNBOUNDID_JAVA_ARGS if quoted to satisfy shellcheck will potentially break the java call
        # shellcheck disable=SC2086
        OUTPUT=$("${PRIVATE_UNBOUNDID_JAVA_BIN}" ${PRIVATE_UNBOUNDID_JAVA_ARGS} com.unboundid.directory.server.tools.InstallDS -t 2>&1 > /dev/null)
        RESULT_CODE=${?}
        if test ${RESULT_CODE} -eq 13; then
            # This is a particular error code that means that the Java version is
            # not supported.  Let InstallDS to display the localized error message
            echo "${OUTPUT}"
            exit 1
        elif test ${RESULT_CODE} -ne 0; then
            echo "ERROR:  The detected Java version could not be used with the set of java"
            echo "arguments ${PRIVATE_UNBOUNDID_JAVA_ARGS}."
            echo "${OUTPUT}"
            echo "  "
            echo "The detected java binary is:"
            echo "${PRIVATE_UNBOUNDID_JAVA_BIN}"
            echo "You must specify the path to a valid Java installation"
            echo "and use a valid set of JVM arguments."
            if test "${SCRIPT_NAME}" != "setup"; then
                echo "  "
                echo "To change the JVM that is used:"
                echo "1. Edit the default.java-home property defined in"
                echo "${INSTANCE_ROOT}/config/java.properties to reference the new JVM."
                echo "2. Run the command-line ${INSTANCE_ROOT}/bin/dsjavaproperties"
                echo "  "
                echo "If the VM reported that it was unable to reserve enough memory, then one"
                echo "of the following is necessary:"
                echo "- If the server was recently stopped, then wait a moment and"
                echo "  run this command again.  Sometimes it takes a while for the JVM"
                echo "  memory to be reclaimed by the operating system."
                echo "- Otherwise, reduce the amount of memory used for this process by editing"
                echo "  java.properties as described above, or reduce the memory used by other"
                echo "  processes including the ZFS file system cache."
            fi
            exit 1
        fi
    fi
}

# Explicitly set the PATH, LD_LIBRARY_PATH, LD_PRELOAD, and other important
# system environment variables for security and compatibility reasons.
set_environment_vars() {

    # Always set the script name even if this function was previously called since
    # the script name may change within the same script.
    SCRIPT_NAME_ARG=-Dcom.unboundid.directory.server.scriptName=${SCRIPT_NAME}
    export SCRIPT_NAME_ARG

    if test -z "${UNBOUNDID_ENV_VARS_SET}"; then
        UNBOUNDID_ENV_VARS_SET=1

        if test "${UNBOUNDID_PATH_OVERRIDE}" = ""; then
            PATH=/bin:/usr/bin
        else
            PATH=$UNBOUNDID_PATH_OVERRIDE
        fi
        LD_LIBRARY_PATH=
        LD_LIBRARY_PATH_32=
        LD_LIBRARY_PATH_64=
        LD_PRELOAD=
        LD_PRELOAD_32=
        LD_PRELOAD_64=

        export PATH LD_LIBRARY_PATH LD_LIBRARY_PATH_32 LD_LIBRARY_PATH_64 \
            LD_PRELOAD LD_PRELOAD_32 LD_PRELOAD_64 UNBOUNDID_ENV_VARS_SET
    fi
}

# Configure the appropriate CLASSPATH.
set_classpath() {
    # This allows the jars and classes to be stored elsewhere.  Use it with
    # extreme caution.
    if test -z "${UNBOUNDID_CLASSPATH_OVERRIDE}"; then
        CLASSPATH=${INSTANCE_ROOT}/classes
        for JAR in "${INSTANCE_ROOT}"/lib/*.jar; do
            test -e "${JAR}" || break
            CLASSPATH=${CLASSPATH}:${JAR}
        done
        for JAR in "${INSTANCE_ROOT}"/lib/jetty/*.jar; do
            test -e "${JAR}" || break
            CLASSPATH=${CLASSPATH}:${JAR}
        done
        for JAR in "${INSTANCE_ROOT}"/lib/extensions/*.jar; do
            test -e "${JAR}" || break
            CLASSPATH=${CLASSPATH}:${JAR}
        done
    else
        CLASSPATH=${UNBOUNDID_CLASSPATH_OVERRIDE}
    fi

    export CLASSPATH
}

# Set a umask so that newly-created files and directories will have the desired
# default permissions
if test -f "${INSTANCE_ROOT}/config/server.umask"; then

    # Check server.umask for CRLF
    # Exit if found
    test_crlf "${INSTANCE_ROOT}/config/server.umask"
    die_on_error 11 ""

    # Cannot follow dynamically generated file
    # shellcheck disable=SC1091
    . "${INSTANCE_ROOT}/config/server.umask"
fi

test -z "${INSTANCE_ROOT}" && INSTANCE_ROOT="${SERVER_ROOT_DIR}"

if test "${SCRIPT_UTIL_CMD}" = "set-full-environment-and-test-java"; then
    set_java_home_and_args
    set_environment_vars
    set_classpath
    test_java
elif test "${SCRIPT_UTIL_CMD}" = "set-full-environment"; then
    set_java_home_and_args
    set_environment_vars
    set_classpath
elif test "${SCRIPT_UTIL_CMD}" = "set-environment-and-test-java"; then
    set_environment_vars
    set_classpath
    test_java
elif test "${SCRIPT_UTIL_CMD}" = "set-java-home-and-args"; then
    set_java_home_and_args
elif test "${SCRIPT_UTIL_CMD}" = "set-environment-vars"; then
    set_environment_vars
elif test "${SCRIPT_UTIL_CMD}" = "set-classpath"; then
    set_classpath
elif test "${SCRIPT_UTIL_CMD}" = "test-java"; then
    test_java
fi
