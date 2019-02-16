#!/usr/bin/env sh
if test "$1" = 'start-server' ; then
	# check if an instance has already been run
	if ! test -d /opt/out/instance ; then	
		# if not, then we deploy the bits to /opt/out
		cp -rf /opt/server/ /opt/out/instance

		if ! test -z "${SERVER_PROFILE_URL}" ; then
			# clone the server profile repo if provided
			git clone ${SERVER_PROFILE_URL} /opt/server-profile
			if ! test -z "${SERVER_PROFILE_BRANCH}" ; then
				cd /opt/server-profile
				git checkout ${SERVER_PROFILE_BRANCH}
				cd -
			fi
			cp -rf /opt/server-profile/* /opt/in
		fi

		if test -d "/opt/in/instance" ; then
			cp -rf /opt/in/instance /opt/out/
		fi
	fi
	sh /opt/postStart.sh &
	tail -F /opt/out/instance/log/pingaccess.log &
	sh -x /opt/out/instance/bin/run.sh
else
	exec "$@"
fi