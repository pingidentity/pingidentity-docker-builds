#!/usr/bin/env sh
${VERBOSE} && set -x

# used to echo the calling shell
CALLING_HOOK=${0}

# echo colorization options
RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
# BLUE_COLOR='\033[0;34m'
# PURPLE_COLOR='\033[0;35m'
NORMAL_COLOR='\033[0m'

# a function to echo a message in the color red
echo_red ()
{
    # shellcheck disable=SC2039
    echo -e "${RED_COLOR}$*${NORMAL_COLOR}"
}

# a function to echo a message in the color green
echo_green ()
{
    # shellcheck disable=SC2039
    echo -e "${GREEN_COLOR}$*${NORMAL_COLOR}"
}

# cat a file to stdout and indent 4 spaces
cat_indent ()
{
    test -f "${1}" && sed 's/^/    /' < "${1}"
}

# a function to base the execution of a script upon the presence or absence of a file
run_if ()
{
    mode=${1}
    shift

    runFile=${1}

    commandSet="sh"
    ${VERBOSE} && commandSet="${commandSet} -x"

    if test -z "${2}" ; then
        if test "${mode}" = "absent" ; then
            echo_red "run_if error, when mode=absent a test file must be provide as a third argument"
            exit 9
        fi
        testFile=${1}
    else
        testFile=${2}
    fi

    if test "${mode}" = "present" ; then
        if test -f "${testFile}" ; then
            ${commandSet} "${runFile}"
        fi
    else
        if ! test -f "${testFile}" ; then
            ${commandSet} "${runFile}"
        fi		
    fi
}

run_either ()
{
    if test -f "${1}" ; then
        sh -x "${1}"
    else
        run_if present "${2}"
    fi
}

die_on_error ()
{
    errorCode=${?}
    exitCode=${1}
    shift
    if test ${errorCode} -ne 0 ; then
        echo_red "CONTAINER FAILURE: $*"
        # wipe the runtime
        rm -rf "${BASE}/out/instance"
        # shellcheck disable=SC2086
        exit ${exitCode}
    fi
}

apply_local_server_profile()
{
    # apply the locally provided files via IN_DIR to the staging directory
    # This is available immediately
    # We do this on every startup such that updates to the IN_DIR contents apply
    # on container restart
    if ! test -z "$( ls -A ${IN_DIR} )" ; then
      # shellcheck disable=SC2086
      cp -af ${IN_DIR}/* "${STAGING_DIR}"
    fi
}

# sleep at least one second and at most the indicated duration
sleep_at_most ()
{
    max=$1
    modulus=$(( max - 1 ))
    # RANDOM tested on Alpine
    # shellcheck disable=SC2039
    result=$(( RANDOM % modulus ))
    duration=$(( result + 1))

    echo "Sleeping up to ${max} seconds (${duration})"
  
    sleep ${duration}
}

echo_green "----- Starting hook: ${CALLING_HOOK}"