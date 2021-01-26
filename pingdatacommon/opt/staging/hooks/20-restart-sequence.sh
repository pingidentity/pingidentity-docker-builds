#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook is called when the container has been built in a prior startup
#- and a configuration has been found.
#
${VERBOSE} && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

echo "Restarting container"

#
# Generate the jvm options
#
jvmOptions=$( getJvmOptions )
_returnCode=${?}
if test ${_returnCode} -ne 0
then
    echo_red "${jvmOptions}"
    container_failure 183 "Invalid JVM options"
fi
# Remove java.properties and re-create it for the current JVM if necessary.
if ! compare_and_save_jvm_settings "${jvmOptions}" || test "${REGENERATE_JAVA_PROPERTIES}" = "true"
then
    echo "JVM options and/or JVM version have changed. Re-generating java.properties for current JVM."
    # re-initialize the current java.properties.  a backup in same location will be created.
    ${SERVER_ROOT_DIR}/bin/dsjavaproperties --initialize ${jvmOptions}
else
    echo "JVM options and version have not changed. Will not generate a new java.properties file."
fi

run_hook "21-update-server-profile.sh"
