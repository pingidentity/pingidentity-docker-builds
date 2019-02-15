#!/bin/sh -x
# check if an instance has already been run
if ! test -d /opt/out/instance ; then	
	# if not, then we deploy the bits to /opt/out
	cp -rf /opt/server/ /opt/out/instance

	if ! test -z "${SERVER_PROFILE_URL}" ; then
		# clone server profile if provided
		git clone ${SERVER_PROFILE_URL} /opt/in
	fi

	if test -d /opt/in/instance ; then
		# lay the configuration on top of vanilla install if provided
		cp -rf /opt/in/instance /opt/out/
	fi
fi
tail -F /opt/out/instance/log/server.log &
sh -x /opt/out/instance/bin/run.sh
