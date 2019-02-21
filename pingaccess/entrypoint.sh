#!/usr/bin/env sh
source /opt/utils.sh

if test "$1" = 'start-server' ; then
	# check if an instance has already been run
	if ! test -d /opt/out/instance ; then	
		# if not, then we deploy the bits to /opt/out
		cp -af /opt/server/ /opt/out/instance

		apply_server_profile
	fi
	sh /opt/postStart.sh &

	cd /opt/out/instance/log
	tail -F ${TAIL_LOG_FILES} &

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