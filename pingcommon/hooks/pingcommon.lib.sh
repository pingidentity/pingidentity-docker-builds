#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build
#
# Common functions used throughout Docker Image Hooks
#
${VERBOSE} && set -x

# capture the calling hook so it can be echo'd later on
CALLING_HOOK=${0}

# File holding State Properties
STATE_PROPERTIES="${STAGING_DIR}/state.properties"

# echo colorization options
if test "${COLORIZE_LOGS}" == "true" ; then
    RED_COLOR='\033[0;31m'
    GREEN_COLOR='\033[0;32m'
    NORMAL_COLOR='\033[0m'
fi

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
    _runFile=${1}

    _commandSet="sh"
    ${VERBOSE} && commandSet="${_commandSet} -x"

    test -f "${_runFile}" && ${_commandSet} "${_runFile}"
}

###############################################################################
# container_failure (exitCode, errorMessage)
#
# echo a CONTAINER FAILURE with passed message
# exit with the exitCode
###############################################################################
container_failure ()
{
    _exitCode=${1} && shift

    echo_red "CONTAINER FAILURE: $*"

    # shellcheck disable=SC2086
    exit ${_exitCode}
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
    _errorCode=${?}
    _exitCode=${1} && shift

    if test ${_errorCode} -ne 0 ; then
        container_failure "${_exitCode}" "$*"
    fi
}

###############################################################################
# run_hook (hookName)
#
# Run the hook passed, and if there is an error, die with the exit number that
# the file starts with.
#
# If the number is > 256, then it will result in a return of that number mod 256
################################################################################
run_hook ()
{
    _hookScript="$1"
    _hookExit=$( echo "${_hookScript}" | sed  's/^\([0-9]*\).*$/\1/g' )

    test -z "${_hookExit}" && _hookExit=99

    run_if_present "${HOOKS_DIR}/${_hookScript}"

    die_on_error ${_hookExit} "Error running ${_hookScript}" || exit ${?}
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
        echo "copying local IN_DIR files (${IN_DIR}) to STAGING_DIR (${STAGING_DIR})"
        # shellcheck disable=SC2086
        cp -af ${IN_DIR}/* "${STAGING_DIR}"
    else
        echo "no local IN_DIR files (${IN_DIR}) found."
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
    _max=$1
    _modulus=$(( _max - 1 ))
    # RANDOM tested on Alpine
    # shellcheck disable=SC2039
    _result=$(( RANDOM % _modulus ))
    _duration=$(( _result + 1))

    echo "Sleeping ${_duration} seconds (max: ${_max})..."
  
    sleep ${_duration}
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
# error_req_var (var)
#
# Check for the requirement, values of a variable and 
# Echo a formatted list of variables and their value.  If the variable is 
# empty, then, a sring of '---- empty ----' will be echoed
###############################################################################
echo_req_vars()
{
    echo_red "# Variable (${_var}) is required."
}

###############################################################################
# echo_vars (var1, var2, ...)
#
# Check for the requirement, values of a variable and
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

    # Find out if there is a _VALIDATION string
    #
    # var_VALIDATION must be of format "true|valid values|message"
    #
    _varValidation="${_var}_VALIDATION"
    _valValidation=$( get_value "${_varValidation}" )

    # Parse the validation value if it exists
    if test ! -z "${_valValidation}" ; then
      _validReq=$( echo "${_valValidation}" | sed  's/^\(.*\)|\(.*\)|\(.*\)$/\1/g' )
      _validVal=$( echo "${_valValidation}" | sed  's/^\(.*\)|\(.*\)|\(.*\)$/\2/g' )
      _validMsg=$( echo "${_valValidation}" | sed  's/^\(.*\)|\(.*\)|\(.*\)$/\3/g' )

      if test "${_validReq}" == "true" -a -z "${_val}" ; then
        _validationFailed="true"
        test "${_validReq}" == "true" && echo_red "         Required: ${_var}"
        test ! -z "${_validVal}" && echo_red "     Valid Values: ${_validVal}"
        test ! -z "${_validMsg}" && echo_red "        More Info: ${_validMsg}"
      fi
    fi
  done
}

###############################################################################
# main  
###############################################################################
echo_green "----- Starting hook: ${CALLING_HOOK}"

# shellcheck source=/dev/null
if test -f "${STAGING_DIR}/env_vars" ; then
    set -o allexport
    . "${STAGING_DIR}/env_vars"
    set +o allexport
fi

# shellcheck source=/dev/null
if test -f "${STATE_PROPERTIES}" ; then
    set -o allexport
    . "${STATE_PROPERTIES}"
    set +o allexport
fi