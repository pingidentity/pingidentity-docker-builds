#!/usr/bin/env sh
set -x

# a function to base the execution of a script upon the presence or absence of a file
run_if ()
{
    mode=${1}
    shift

    runFile=${1}

    if test -z "${2}" ; then
        if test "${mode}" = "absent" ; then
            echo "error, when mode=absent a test file must be provide as a third argument"
            exit 9
        fi
        testFile=${1}
    else
        testFile=${2}
    fi

    if test "${mode}" = "present" ; then
        if test -f "${testFile}" ; then
            sh -x "${runFile}"
        fi
    else
        if ! test -f "${testFile}" ; then
            sh -x "${runFile}"
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
        echo "CONTAINER FAILURE: $*"
        # wipe the runtime
        rm -rf /opt/out/instance
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
    sleep ${duration}
}