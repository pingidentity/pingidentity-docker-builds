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