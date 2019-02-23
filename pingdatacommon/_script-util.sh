#!/bin/sh
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
#      Portions Copyright 2008-2018 Ping Identity Corporation
#      Portions Copyright 2008 Sun Microsystems, Inc.

#
# function that sets the java home
#
set_java_home_and_args() {
  PRIVATE_UNBOUNDID_JAVA_BIN=${UNBOUNDID_JAVA_BIN}
  PRIVATE_UNBOUNDID_JAVA_HOME=${UNBOUNDID_JAVA_HOME}
  PRIVATE_UNBOUNDID_JAVA_ARGS=${UNBOUNDID_JAVA_ARGS}
  export PRIVATE_UNBOUNDID_JAVA_BIN PRIVATE_UNBOUNDID_JAVA_HOME PRIVATE_UNBOUNDID_JAVA_ARGS
  if test -f "${INSTANCE_ROOT}/lib/set-java-home"
  then
    . "${INSTANCE_ROOT}/lib/set-java-home"
  fi

  if test "${UNBOUNDID_TESTING}" = "true"
  then
    PRIVATE_UNBOUNDID_JAVA_ARGS="${PRIVATE_UNBOUNDID_JAVA_ARGS} ${UNBOUNDID_NOVERIFY_ARG}"
    export PRIVATE_UNBOUNDID_JAVA_ARGS
  fi

  if test -z "${PRIVATE_UNBOUNDID_JAVA_BIN}"
  then
    if test -z "${PRIVATE_UNBOUNDID_JAVA_HOME}"
    then
      if test -z "${JAVA_BIN}"
      then
        if test -z "${JAVA_HOME}"
        then
          PRIVATE_UNBOUNDID_JAVA_BIN=`which java 2> /dev/null`
          if test ${?} -eq 0
          then
            export PRIVATE_UNBOUNDID_JAVA_BIN
          else
            # Check to see whether this is the setup script in which case echo a more user friendly
            # reference to JAVA_HOME without referring to non-existent files generated by setup.
            if test "${SCRIPT_NAME}" != "setup"
            then
              echo "Please set UNBOUNDID_JAVA_HOME to the root of a supported Java installation"
              echo "or edit the java.properties file and then run the dsjavaproperties script to"
              echo "specify the Java version to be used"
            else
              echo "Please set JAVA_HOME to the root of a supported Java installation"
            fi
            exit 1
          fi
        else
          PRIVATE_UNBOUNDID_JAVA_BIN="${JAVA_HOME}/bin/java"
          export PRIVATE_UNBOUNDID_JAVA_BIN
        fi
      else
        PRIVATE_UNBOUNDID_JAVA_BIN="${JAVA_BIN}"
        export PRIVATE_UNBOUNDID_JAVA_BIN
      fi
    else
      PRIVATE_UNBOUNDID_JAVA_BIN="${PRIVATE_UNBOUNDID_JAVA_HOME}/bin/java"
      export PRIVATE_UNBOUNDID_JAVA_BIN
    fi
  fi
}

# Determine whether the detected Java environment is acceptable for use.
test_java() {
  if test -z "${PRIVATE_UNBOUNDID_JAVA_ARGS}"
  then
    OUTPUT=`"${PRIVATE_UNBOUNDID_JAVA_BIN}" com.unboundid.directory.server.tools.InstallDS -t 2>&1 >/dev/null`
    RESULT_CODE=${?}
    if test ${RESULT_CODE} -eq 13
    then
      # This is a particular error code that means that the Java version is
      # not supported.  Let InstallDS to display the localized error message
      echo "${OUTPUT}"
      exit 1
    elif test ${RESULT_CODE} -ne 0
    then
      echo "ERROR:  The detected Java version could not be used."
      echo "${OUTPUT}"
      echo "  "
      echo "The detected java binary is:"
      echo "${PRIVATE_UNBOUNDID_JAVA_BIN}"
      echo "You must specify the path to a valid Java installation"
      echo "and use a valid set of JVM arguments."
      if test "${SCRIPT_NAME}" != "setup"
      then
        echo "  "
        echo "To change the JVM that is used:"
        echo "1. Edit the default.java-home property defined in"
        echo "${INSTANCE_ROOT}/config/java.properties to reference the new JVM."
        echo "2. Run the command-line ${INSTANCE_ROOT}/bin/dsjavaproperties"
      fi
      exit 1
    fi
  else
    OUTPUT=`"${PRIVATE_UNBOUNDID_JAVA_BIN}" ${PRIVATE_UNBOUNDID_JAVA_ARGS} com.unboundid.directory.server.tools.InstallDS -t 2>&1 >/dev/null`
    RESULT_CODE=${?}
    if test ${RESULT_CODE} -eq 13
    then
      # This is a particular error code that means that the Java version is
      # not supported.  Let InstallDS to display the localized error message
      echo "${OUTPUT}"
      exit 1
    elif test ${RESULT_CODE} -ne 0
    then
      echo "ERROR:  The detected Java version could not be used with the set of java"
      echo "arguments ${PRIVATE_UNBOUNDID_JAVA_ARGS}."
      echo "${OUTPUT}"
      echo "  "
      echo "The detected java binary is:"
      echo "${PRIVATE_UNBOUNDID_JAVA_BIN}"
      echo "You must specify the path to a valid Java installation"
      echo "and use a valid set of JVM arguments."
      if test "${SCRIPT_NAME}" != "setup"
      then
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

  if test -z "${UNBOUNDID_ENV_VARS_SET}"
  then
    UNBOUNDID_ENV_VARS_SET=1

    if test "${UNBOUNDID_PATH_OVERRIDE}" = ""
    then
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

    # If priocntl is available (and it will be on Solaris), then try to use it
    # to enable the fixed-priority scheduler.
    if test -f /usr/bin/priocntl
    then
      /usr/bin/priocntl -s -c FX $$ > /dev/null 2>&1
    fi

    # If libumem is available (and it will be on Solaris), then try to use it.
    if test -f /usr/lib/libumem.so
    then
      LD_PRELOAD=${LD_PRELOAD}:libumem.so
      LD_PRELOAD_32=${LD_PRELOAD_32}:libumem.so
      LD_PRELOAD_64=${LD_PRELOAD_64}:libumem.so
    fi

    # Try to set the number of available file descriptors.  If the file
    # config/num-file-descriptors exists with a NUM_FILE_DESCRIPTORS
    # environment variable (or that environment variable is set through some
    # other form), then we'll use that value.  Otherwise, we'll use a default
    # of 65535.
    if test -z "${NUM_FILE_DESCRIPTORS}"
    then
      if test -s "${INSTANCE_ROOT}/config/num-file-descriptors"
      then
        . "${INSTANCE_ROOT}/config/num-file-descriptors"
      fi

      if test -z "${NUM_FILE_DESCRIPTORS}"
      then
        NUM_FILE_DESCRIPTORS="65535"
      fi
    fi

    if test "$(uname)" != "Darwin"
    then
      ulimit -n ${NUM_FILE_DESCRIPTORS} > ${INSTANCE_ROOT}/logs/ulimit-num-file-descriptors.out 2>&1
      ACTUAL_FDS=`ulimit -n`
      if test "${NUM_FILE_DESCRIPTORS}" -ne "${ACTUAL_FDS}"
      then
        echo >&2 "WARNING:  Unable to set the file descriptor limit to ${NUM_FILE_DESCRIPTORS}."
        echo >&2 "          The number of available descriptors is ${ACTUAL_FDS}."
        echo >&2 "          This may interfere with the operation of this process."
        echo >&2 "          See the Administration Guide for information about"
        echo >&2 "          configuring system file descriptor limits, and for"
        echo >&2 "          configuring the number of file descriptors the server"
        echo >&2 "          should attempt to use."
        echo >&2
      fi
    else
      ulimit -n ${NUM_FILE_DESCRIPTORS} > ${INSTANCE_ROOT}/logs/ulimit-num-file-descriptors.out 2>&1
      RETURN_CODE=$?
      if test ${RETURN_CODE} -ne 0
      then
        echo >&2 "WARNING:  Unable to set the file descriptor limit to ${NUM_FILE_DESCRIPTORS}."
        echo >&2 "          This may interfere with the operation of this process."
        echo >&2 "          See the Administration Guide for information about"
        echo >&2 "          configuring system file descriptor limits, and for"
        echo >&2 "          configuring the number of file descriptors the server"
        echo >&2 "          should attempt to use."
        echo >&2
      fi
    fi

    # Try to set the number of processes available to a single user. On Linux,
    # a thread is considered a user process. If the file config/num-user-processes
    # exists with a NUM_USER_PROCESSES environment variable (or that environment
    # variable is set through some other form), then we'll use that value.
    # Otherwise, on Linux only, we'll use a minimum of 16383, and on other
    # platforms we will use the existing value.

    # The ulimit option for the number of processes is -p on Ubuntu.
    ulimit -u >/dev/null 2>&1
    if test $? -eq 0 && ! test -f /etc/alpine-release
    then
      PROCESSES_OPTION=-u
    else
      PROCESSES_OPTION=-p
    fi

    if test -z "${NUM_USER_PROCESSES}"
    then
      if test -s "${INSTANCE_ROOT}/config/num-user-processes"
      then
        . "${INSTANCE_ROOT}/config/num-user-processes"
      fi

      if test "$(uname)" = "Linux" -a -z "${NUM_USER_PROCESSES}"
      then
        ACTUAL_PROCESSES=`ulimit ${PROCESSES_OPTION}`
        if test "${ACTUAL_PROCESSES}" -lt 16383 2>/dev/null
        then
          NUM_USER_PROCESSES="16383"
        fi
      fi
    fi

    rm -f "${INSTANCE_ROOT}/logs/ulimit-num-user-processes.out"
    if test ! -z "${NUM_USER_PROCESSES}"
    then
      if test "$(uname)" != "Darwin"
      then
        ulimit ${PROCESSES_OPTION} ${NUM_USER_PROCESSES} > ${INSTANCE_ROOT}/logs/ulimit-num-user-processes.out 2>&1
        ACTUAL_PROCESSES=`ulimit ${PROCESSES_OPTION}`
        if test "${NUM_USER_PROCESSES}" -ne "${ACTUAL_PROCESSES}"
        then
          echo "WARNING:  Unable to set the processes limit to ${NUM_USER_PROCESSES}."
          echo "          The number of available processes is ${ACTUAL_PROCESSES}."
          echo "          This may interfere with the operation of this process."
          echo "          See the Administration Guide for information about"
          echo "          configuring system limits for the number of user"
          echo "          processes, and for configuring the number of processes"
          echo "          the server should attempt to use."
          echo
        fi
      else
        ulimit ${PROCESSES_OPTION} ${NUM_USER_PROCESSES} > ${INSTANCE_ROOT}/logs/ulimit-num-user-processes.out 2>&1
        RETURN_CODE=$?
        if test ${RETURN_CODE} -ne 0
        then
          echo "WARNING:  Unable to set the processes limit to ${NUM_USER_PROCESSES}."
          echo "          This may interfere with the operation of this process."
          echo "          See the Administration Guide for information about"
          echo "          configuring system limits for the number of user"
          echo "          processes, and for configuring the number of processes"
          echo "          the server should attempt to use."
          echo
        fi
      fi
    fi

    # Do not delete the output file unless it is empty. The server
    # will log a warning at start-up if it finds a non-empty output file.
    for f in ulimit-num-file-descriptors.out ulimit-num-user-processes.out
    do
      if test -f "${INSTANCE_ROOT}/logs/${f}"
      then
        if test ! -s "${INSTANCE_ROOT}/logs/${f}"
        then
          rm -f "${INSTANCE_ROOT}/logs/${f}"
        fi
      fi
    done

    export PATH LD_LIBRARY_PATH LD_LIBRARY_PATH_32 LD_LIBRARY_PATH_64 \
         LD_PRELOAD LD_PRELOAD_32 LD_PRELOAD_34 UNBOUNDID_ENV_VARS_SET
  fi

  # set Postgres environment variables
  set_pg_env
}

# Configure the appropriate CLASSPATH.
set_classpath() {
  # This allows the jars and classes to be stored elsewhere.  Use it with
  # extreme caution.
  if test "${UNBOUNDID_CLASSPATH_OVERRIDE}" = ""
  then
    CLASSPATH=${INSTANCE_ROOT}/classes
    for JAR in "${INSTANCE_ROOT}"/lib/*.jar
    do
      [ -e "${JAR}" ] || break
      CLASSPATH=${CLASSPATH}:${JAR}
    done
    for JAR in "${INSTANCE_ROOT}"/lib/jetty/*.jar
    do
      [ -e "${JAR}" ] || break
      CLASSPATH=${CLASSPATH}:${JAR}
    done
    for JAR in "${INSTANCE_ROOT}"/lib/extensions/*.jar
    do
      [ -e "${JAR}" ] || break
      CLASSPATH=${CLASSPATH}:${JAR}
    done
  else
    CLASSPATH=${UNBOUNDID_CLASSPATH_OVERRIDE}
  fi

  export CLASSPATH
}

# Configure the appropriate Postgres environment.
set_pg_env() {
  PG_BIN_DIR=
  PG_DB_CTRL=
  PG_BIN_TMP=${INSTANCE_ROOT}/pgsql-9.2.4

  if test -f "${PG_BIN_TMP}/bin/initdb"
  then
    PG_BIN_DIR="${PG_BIN_TMP}/bin"
    PG_DB_CTRL="${PG_BIN_TMP}/bin/db_ctrl"
  fi

  if test -f "${PG_BIN_TMP}/bin/64/initdb"
  then
    PG_BIN_DIR="${PG_BIN_TMP}/bin/64"
    PG_DB_CTRL="${PG_BIN_TMP}/bin/64/db_ctrl"
  fi

  export PG_BIN_DIR PG_DB_CTRL
}

# Set a umask so that newly-created files and directories will have the desired
# default permissions
if test -f "${INSTANCE_ROOT}/config/server.umask"
then
  . "${INSTANCE_ROOT}/config/server.umask"
fi

# Attempt to determine the width and height of the user's terminal
# specifying TERM if it is missing to avoid tput error messages.
if [ -n "${TERM:+x}" ]
then
  TPUT="/usr/bin/tput"
else
  TPUT="/usr/bin/tput -T xterm"
fi
if test -f "/usr/bin/tput"
then
  COLUMNS=`${TPUT} cols`
  if test "${COLUMNS}" != ""
  then
    export COLUMNS
  fi

  LINES=`${TPUT} lines`
  if test "${LINES}" != ""
  then
    export LINES
  fi
fi

if test "${INSTANCE_ROOT}" = ""
then
  # Capture the current working directory so that we can change to it later.
  # Then capture the location of this script and the server instance
  # root so that we can use them to create appropriate paths.
  WORKING_DIR=`pwd`

  cd "`dirname "${0}"`"
  cd ..
  INSTANCE_ROOT=`pwd`
  cd "${WORKING_DIR}"
fi

if test "${SCRIPT_UTIL_CMD}" = "set-full-environment-and-test-java"
then
  set_java_home_and_args
  set_environment_vars
  set_classpath
  test_java
elif test "${SCRIPT_UTIL_CMD}" = "set-full-environment"
then
  set_java_home_and_args
  set_environment_vars
  set_classpath
elif test "${SCRIPT_UTIL_CMD}" = "set-environment-and-test-java"
then
  set_environment_vars
  set_classpath
  test_java
elif test "${SCRIPT_UTIL_CMD}" = "set-java-home-and-args"
then
  set_java_home_and_args
elif test "${SCRIPT_UTIL_CMD}" = "set-environment-vars"
then
  set_environment_vars
elif test "${SCRIPT_UTIL_CMD}" = "set-classpath"
then
  set_classpath
elif test "${SCRIPT_UTIL_CMD}" = "test-java"
then
  test_java
fi
