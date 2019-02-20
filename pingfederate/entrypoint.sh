#!/usr/bin/env sh
set -x
source /opt/utils.sh

# check if an instance has already been run
if ! test -d /opt/out/instance ; then	
	# if not, then we deploy the bits to /opt/out
	cp -af /opt/server/ /opt/out/instance

	apply_server_profile

	if test -d /opt/in/instance ; then
		# lay the configuration on top of vanilla install if provided
		cp -af /opt/in/instance /opt/out/
	fi
fi
tail -F /opt/out/instance/log/server.log &
sh -x /opt/out/instance/bin/run.sh
