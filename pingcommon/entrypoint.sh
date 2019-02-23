#!/usr/bin/env sh
set -x

source ${BASE}/utils.sh

test -f ${BASE}/library.sh && source ${BASE}/library.sh

if test "$1" = "start-server" ; then
    run_if present ${IN_DIR}/hooks/00-immediate-startup.sh

    if test -f ${IN_DIR}/hooks/first_time_sequence.sh ; then
        sh ${IN_DIR}/hooks/first_time_sequence.sh
    else
        run_if present ${BASE}/first_time_sequence.sh
    fi

    run_if present ${IN_DIR}/hooks/50-before-post-start.sh

    if test -f ${IN_DIR}/hooks/80-post-start.sh ; then
        # run post-start hook
        sh -x ${IN_DIR}/hooks/80-post-start.sh &
    else
        # if no custom post start hook is provided, run the default post start
        run_if present /opt/postStart.sh &
    fi

    cd ${TAIL_LOG_DIR}
    tail -F ${TAIL_LOG_FILES} &

    if test -z "${2}" ; then
        # replace the shell with foreground server
        if test -z "${STARTUP_COMMAND}" ; then
            echo "*** NO CONTAINER STARTUP COMMAND PROVIDED ***"
            exit 90
        else
            exec ${STARTUP_COMMAND}
        fi
    else
        # start server in the background and execute the provided command (useful for self-test)
        ${STARTUP_COMMAND} &
        shift
        exec $@
    fi
else
    # in case the container should be run without the server instance
    exec $@
fi