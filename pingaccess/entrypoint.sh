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
	tail -F /opt/out/instance/log/pingaccess.log &
	sh -x /opt/out/instance/bin/run.sh
else
	exec "$@"
fi