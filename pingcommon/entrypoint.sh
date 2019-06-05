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
    run_if_present "${HOOKS_DIR}/01-start-server.sh"
    die_on_error 01 "Start script failed" || exit ${?} 

    if ! test -d "${SERVER_ROOT_DIR}" ; then
        ## FIRST TIME EXECUTION OF THE CONTAINER
        run_if_present "${HOOKS_DIR}/10-start-sequence.sh"
        die_on_error 10 "First time sequence failed" || exit ${?}
    else
        ## RESTART
        run_if_present "${HOOKS_DIR}/20-restart-sequence.sh"
        die_on_error 19 "Restart sequence failed" || exit ${?}
    fi

    run_if_present "${HOOKS_DIR}/50-before-post-start.sh" 
    die_on_error 50 "Before post-start hook failed" || exit ${?}

    # The 80-post-start.sh is placed in the background, at tenically runs
    # before the service is actually started.  The post start SHOULD 
    # poll the service (i.e. curl commands or ldapsearch or ...) to verify it 
    # is running before performing the actual post start tasks.
    run_if_present "${HOOKS_DIR}/80-post-start.sh" &

    if ! test -z "${TAIL_LOG_FILES}" ; then
        # shellcheck disable=SC2086
        echo "Tailing log files (${TAIL_LOG_FILES})"
        tail -F ${TAIL_LOG_FILES} 2>/dev/null &
    fi

    # If there is no startup command provided, provide error message and exit.
    if test -z "${STARTUP_COMMAND}" ; then
        echo_red "*** NO CONTAINER STARTUP COMMAND PROVIDED ***"
        exit 90
    fi

    # If a command is provided after the "start-server" on the container start, then
    # startup the server in the background and then run that command.  A good example 
    # is to run a shell after the startup.
    #
    # Example: 
    #   run docker ....                        # Starts server in foreground
    #   run docker .... start-server           # Starts server in foreground (same as previous)
    #   run docker .... start-server /bin/sh   # Starts server in background and runs shell
    #   run docker .... /bin/sh                # Doesn't start the server but drops into a shell
    if test -z "$*" ; then
        # replace the shell with foreground server
        echo_green "Starting server in foreground: (${STARTUP_COMMAND} ${STARTUP_FOREGROUND_OPTS})"
        exec "${STARTUP_COMMAND}" ${STARTUP_FOREGROUND_OPTS}
    else
        # start server in the background and execute the provided command (useful for self-test)
        echo_green "Starting server in background: (${STARTUP_COMMAND} ${STARTUP_BACKGROUND_OPTS})"
        # shellcheck disable=SC2086
        "${STARTUP_COMMAND}" ${STARTUP_BACKGROUND_OPTS} &
        echo_green "Running command: $@"
        exec "$@"
    fi
else
    echo_green "Running command: $@"
    exec "$@"
fi