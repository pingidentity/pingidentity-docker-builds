#!/usr/bin/env sh


# a function to base the execution of a script upon the presence or absence of a file
function run_if ()
{
	mode=$1
	shift

	runFile=$1


	if test -z "$2" ; then
    if test "${mode}" = "absent" ; then
      echo "error, when mode=absent a test file must be provide as a third argument"
      exit 9
    fi
		testFile=$1
	else
		testFile=$2
	fi

	if test $mode = "present" ; then
		if test -f "${testFile}" ; then
			sh ${runFile}
		fi
	else
		if ! test -f "${testFile}" ; then
			sh ${runFile}
		fi		
	fi
}

function die_on_error ()
{
  errorCode=$?
  exitCode=$1
  shift
  if test ${errorCode} -ne 0 ; then
    echo "CONTAINER FAILURE: $@"
    rm -rf /opt/out/instance
    exit ${exitCode}
  fi
}

function apply_server_profile ()
{
  if ! test -z "${SERVER_PROFILE_URL}" ; then
    # deploy configuration if provided
    git clone ${SERVER_PROFILE_URL} /opt/server-profile
    die_on_error 78 "Git clone failure" 
    if ! test -z "${SERVER_PROFILE_BRANCH}" ; then
      cd /opt/server-profile
      git checkout ${SERVER_PROFILE_BRANCH}
      cd -
    fi
    cp -af /opt/server-profile/${SERVER_PROFILE_PATH}/* /opt/in
  fi
  test -d ${IN_DIR}/instance && cp -af ${IN_DIR}/instance ${OUT_DIR}
}