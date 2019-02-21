#!/usr/bin/env sh
source /opt/utils.sh

if test "$1" = 'start-server' ; then
	run_if present ${IN_DIR}/hooks/00-immediate-startup.sh

	# check if an instance has already been run
	if ! test -d /opt/out/instance ; then	
		# if not, then we deploy the bits to /opt/out
		cp -af /opt/server/ /opt/out/instance

		apply_server_profile
	fi

	cd /opt/out/instance/log
	tail -F ${TAIL_LOG_FILES} &
	
	run_if present ${IN_DIR}/hooks/50-before-post-start.sh

	# Kick off the post start script in the background. This will set up
	# replication when the server is started.
	run_if present ${IN_DIR}/hooks/80-post-start.sh &

	# if no custom post start hook is provided, run the default post start
	run_if absent /opt/postStart.sh ${IN_DIR}/hooks/80-post-start.sh  &

	if test -z "${2}" ; then
		# replace the shell with foreground server
		exec sh /opt/out/instance/bin/run.sh
	else
		# start server in the background and execute the provided command (useful for self-test)
		sh /opt/out/instance/bin/run.sh &
		shift
		exec "$@"
	fi
else
	exec "$@"
fi