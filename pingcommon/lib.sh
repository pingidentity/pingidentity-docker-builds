#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build
#
# Common functions used throughout Docker Image Hooks
#
${VERBOSE} && set -x

# capture the calling hook so it can be echo'd later on
CALLING_HOOK=${0}

# echo colorization options
RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
NORMAL_COLOR='\033[0m'

###############################################################################
# echo_red (message)
#
# Echo a message in the color red
###############################################################################
echo_red ()
{
    # shellcheck disable=SC2039
    echo -e "${RED_COLOR}$*${NORMAL_COLOR}"
}

###############################################################################
# echo_green (message)
#
# Echos a message in the color green
###############################################################################
echo_green ()
{
    # shellcheck disable=SC2039
    echo -e "${GREEN_COLOR}$*${NORMAL_COLOR}"
}

###############################################################################
# cat_indent (file)
#
# cat a file to stdout and indent 4 spaces
###############################################################################
cat_indent ()
{
    test -f "${1}" && sed 's/^/    /' < "${1}"
}

###############################################################################
# run_if_present (script)
#
# runs a script, if the script is present
###############################################################################
run_if_present ()
{
    runFile=${1}

    commandSet="sh"
    ${VERBOSE} && commandSet="${commandSet} -x"

    test -f "${runFile}" && ${commandSet} "${runFile}"
}

###############################################################################
# container_failure (exitCode, errorMessage)
#
# echo a CONTAINER FAILURE with passed message
# Wipe the runtime
# exit with the exitCode
###############################################################################
container_failure ()
{
    exitCode=${1} && shift

    echo_red "CONTAINER FAILURE: $*"
    # wipe the runtime
    rm -rf "${BASE}/out/instance"
    # shellcheck disable=SC2086
    exit ${exitCode}
}

###############################################################################
# die_on_error (exitCode, errorMessage)
#
# If the return code of the previous command is non-zero, then:
#    echo a CONTAINER FAILURE with passed message
#    Wipe the runtime
#    exit with the exitCode
###############################################################################
die_on_error ()
{
    errorCode=${?}
    exitCode=${1} && shift

    if test ${errorCode} -ne 0 ; then
        container_failure "$exitCode" "$*"
    fi
}

###############################################################################
# apply_local_server_profile ()
#
# apply the locally provided files via IN_DIR to the staging directory
# We do this on every startup such that updates to the IN_DIR contents apply
# on container restart
###############################################################################
apply_local_server_profile()
{
    if ! test -z "$( ls -A ${IN_DIR} )" ; then
      # shellcheck disable=SC2086
      cp -af ${IN_DIR}/* "${STAGING_DIR}"
    fi
}

###############################################################################
# apply_local_server_profile (num_seconds)
#
# Sleep at least one second and at most the indicated duration and 
# echos a message
###############################################################################
sleep_at_most ()
{
    max=$1
    modulus=$(( max - 1 ))
    # RANDOM tested on Alpine
    # shellcheck disable=SC2039
    result=$(( RANDOM % modulus ))
    duration=$(( result + 1))

    echo "Sleeping up to ${duration} seconds (max: ${max})"
  
    sleep ${duration}
}

###############################################################################
# get_value (variable)
#
# Get the value of a variable passed, preserving any spaces
###############################################################################
get_value ()
{
    # the following will preserve spaces in the printf
    IFS="%%"
    eval printf '%s' "\${${1}}"
    unset IFS
}

###############################################################################
# echo_header (line1, line2, ...)
#
# Echo a header, with each line passed on separate lines
###############################################################################
echo_header()
{
  echo "##################################################################################"

  while (test ! -z "${1}")
  do
    _msg=${1} && shift

    echo "#    ${_msg}"
  done

  echo "##################################################################################"
}

###############################################################################
# echo_vars (var1, var2, ...)
#
# Echo a formatted list of variables and their value.  If the variable is 
# empty, then, a sring of '---- empty ----' will be echoed
###############################################################################
echo_vars()
{
  while (test ! -z ${1})
  do
    _var=${1} && shift
    _val=$( get_value "${_var}" )

    printf "    %30s : %s\n" "${_var}" "${_val:---- empty ---}"
  done
}


###############################################################################
# main  
###############################################################################
echo_green "----- Starting hook: ${CALLING_HOOK}"