#!/usr/bin/env sh
${VERBOSE} && set -x

# shellcheck source=lib.sh
. "${BASE}/lib.sh"


if test "$1" = "start-server" ; then
    shift

    apply_local_server_profile

    # if a git repo is provided, it has not yet been cloned
    # the only way to provide this hook is via the IN_DIR volume
    # aka "local server-profile"
    # or a previous run of the container that would then checkout
    # hence the name on-restart
    #
    run_if present "${HOOKS_DIR}/00-on-restart.sh"

    if ! test -d "${SERVER_ROOT_DIR}" ; then
        ## FIRST TIME EXECUTION OF THE CONTAINER
        run_if present "${HOOKS_DIR}/10-first-time-sequence.sh"
        die_on_error 10 "First time sequence failed" || exit ${?}
    else
        ## RESTART
        run_if present "${HOOKS_DIR}/19-update-server-profile.sh"
        die_on_error 19 "Restart sequence failed" || exit ${?}
    fi

    run_if present "${HOOKS_DIR}/50-before-post-start.sh" 
    die_on_error 50 "Before post-start hook failed" || exit ${?}

    run_if present "${HOOKS_DIR}/80-post-start.sh" &

    if ! test -z "${TAIL_LOG_FILES}" ; then
        # shellcheck disable=SC2086
        tail -F ${TAIL_LOG_FILES} 2>/dev/null &
    fi

    if test -z "$*" ; then
        # replace the shell with foreground server
        if test -z "${STARTUP_COMMAND}" ; then
            echo "*** NO CONTAINER STARTUP COMMAND PROVIDED ***"
            exit 90
        else
            # shellcheck disable=SC2086
            exec "${STARTUP_COMMAND}" ${STARTUP_FOREGROUND_OPTS}
        fi
    else
        # start server in the background and execute the provided command (useful for self-test)
        # shellcheck disable=SC2086
        "${STARTUP_COMMAND}" ${STARTUP_BACKGROUND_OPTS} &
        exec "$@"
    fi
else
    exec "$@"
fi