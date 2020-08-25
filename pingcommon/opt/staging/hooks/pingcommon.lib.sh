#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build
#
# Common functions used throughout Docker Image Hooks
#
${VERBOSE} && set -x

# capture the calling hook so it can be echo'd later on
CALLING_HOOK=${0}

# check for devops file in docker secrets location
# shellcheck disable=SC1090
test -f "/run/secrets/${PING_IDENTITY_DEVOPS_FILE}" && . "/run/secrets/${PING_IDENTITY_DEVOPS_FILE}"

# echo colorization options
if test "${COLORIZE_LOGS}" = "true"
then
    RED_COLOR='\033[0;31m'
    GREEN_COLOR='\033[0;32m'
    YELLOW_COLOR='\033[0;33m'
    NORMAL_COLOR='\033[0m'
fi

#
#
#  Some extremely basic functions to make life with variables a bit easier
#
#
toLower ()
{
    printf "%s" "${*}"|tr '[:upper:]' '[:lower:]'
}

toLowerVar ()
{
    toLower "$(eval printf "%s" \$"${1}")"
}

lowerVar()
{
    eval "${1}=$(toLowerVar "${1}")"
}

toUpper ()
{
    printf "%s" "${*}"|tr '[:lower:]' '[:upper:]'
}

toUpperVar ()
{
    toUpper "$(eval printf "%s" \$"${1}")"
}

upperVar()
{
    eval "${1}=$(toUpperVar "${1}")"
}

#
# Common wrapper for curl to make reliable calls
#
_curl ()
{
    _httpResultCode=$(
        curl \
            --get \
            --silent \
            --show-error \
            --write-out '%{http_code}' \
            --location \
            --connect-timeout 2 \
            --retry 6 \
            --retry-max-time 30 \
            --retry-connrefused \
            --retry-delay 3 \
            "${@}"
    )
    test "${_httpResultCode}" = "200"
    return ${?}
}

#
# Stable function to retrieve OS information
#
parseOSRelease ()
{
    test -n "${1}" && awk '$0~/^'"${1}"'=/ {split($1,id,"="); gsub(/"/,"",id[2]); print id[2];}' </etc/os-release 2>/dev/null
}

# The OS ID is all lowercase
getOSID ()
{
    parseOSRelease ID
}

getOSVersion ()
{
    parseOSRelease VERSION
}

# The name is often pretty-printed
getOSName ()
{
    parseOSRelease NAME
}

isOS ()
{
    _targetOS="${1}"
    _currentOS="$(getOSID)"
    test -n "${_targetOS}" && test "${_targetOS}" = "${_currentOS}"
    return ${?}
}

###############################################################################
# echo_red (message)
#
# Prints a message in the color red
###############################################################################
echo_red ()
{
    echoEscape="-e"
    if isOS ubuntu || test "${COLORIZE_LOGS}" != "true"
    then
        echoEscape=""
    fi
    # shellcheck disable=SC2086
    echo ${echoEscape} "${RED_COLOR}$*${NORMAL_COLOR}"
}

###############################################################################
# echo_green (message)
#
# Prints a message in the color green
###############################################################################
echo_green ()
{
    echoEscape="-e"
    if isOS ubuntu || test "${COLORIZE_LOGS}" != "true"
    then
        echoEscape=""
    fi
    # shellcheck disable=SC2086
    echo ${echoEscape} "${GREEN_COLOR}$*${NORMAL_COLOR}"
}

###############################################################################
# echo_yellow (message)
#
# Prints a message in the color yellow
###############################################################################
echo_yellow ()
{
    echoEscape="-e"
    if isOS ubuntu || test "${COLORIZE_LOGS}" != "true"
    then
        echoEscape=""
    fi
    # shellcheck disable=SC2086
    echo ${echoEscape} "${YELLOW_COLOR}$*${NORMAL_COLOR}"
}

###############################################################################
# echo_bar ()
#
# Echos a bar of 80 hash marks
###############################################################################
echo_bar ()
{
    printf "################################################################################\n"
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
    ${VERBOSE} && _commandSet="${_commandSet} -x"
    if test -f "${_runFile}"
    then
        ${_commandSet} "${_runFile}"
        return ${?}
    else
        echo ""
    fi
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

    if test "$(toLower "${UNSAFE_CONTINUE_ON_ERROR}")" = "true"; then
        echo_red "################################################################################"
        echo_red "################################### WARNING ####################################"
        echo_red "################################################################################"
        echo_red "#  ERROR (${_exitCode}): $*"
        echo_red "################################################################################"
        echo_red "#"
        echo_red "#  Container would normally fail at this point, however the   "
        echo_red "#  variable UNSAFE_CONTINUE_ON_ERROR is set to '${UNSAFE_CONTINUE_ON_ERROR}'"
        echo_red "#"
        echo_red "#  Container will continue with unknown potential side-effects"
        echo_red "#  and consequences!!!"
        echo_red "#"
        echo_red "################################################################################"
    else
        echo_red "CONTAINER FAILURE: $*"
        # shellcheck disable=SC2086
        exit ${_exitCode}
    fi
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

    if test ${_errorCode} -ne 0
    then
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


    run_if_present "${HOOKS_DIR}/${_hookScript}.pre"
    die_on_error ${_hookExit} "Error running ${_hookScript}.pre" || exit ${?}

    run_if_present "${HOOKS_DIR}/${_hookScript}"
    die_on_error ${_hookExit} "Error running ${_hookScript}" || exit ${?}

    run_if_present "${HOOKS_DIR}/${_hookScript}.post"
    die_on_error ${_hookExit} "Error running ${_hookScript}.post" || exit ${?}
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
    if test -n "${IN_DIR}" && test -n "$( ls -A "${IN_DIR}" 2>/dev/null )"
    then
        echo "copying local IN_DIR files (${IN_DIR}) to STAGING_DIR (${STAGING_DIR})"
        # shellcheck disable=SC2086
        copy_files "${IN_DIR}" "${STAGING_DIR}"
    else
        echo "no local IN_DIR files (${IN_DIR}) found."
    fi
}

###############################################################################
# copy_files (src, dst)
#
# Copy files from the source to the destination directory, following all
# symlinks. Directory structure is preserved, but empty directories are not
# copied. Destination must be a directory and is created if it doesn't already
# exist.
###############################################################################
copy_files()
{
    SRC="$1"
    DST="$2"

    if ! test -e "${DST}"
    then
        echo "copy_files - dst dir (${DST}) does not exist - will create it"
        mkdir -p "${DST}"
    elif ! test -d "${DST}"
    then
        echo "Error: copy_files - dst (${DST}) must be a directory"
        exit 1
    fi

    ( cd "${SRC}" && find . -type f -exec cp -afL --parents '{}' "${DST}" \; )
}

###############################################################################
# security_filename_check (path)
#
#   path - Where to find any files following pattern
#   pattern - pattern to search for (i.e. *.jwk)
#
# check files in the path for potential security issues based on pattern passed
###############################################################################
security_filename_check()
{
    _scPath="${1}"
    _patternToCheck="${2}"

    test -z "${_totalSecurityViolations}" && _totalSecurityViolations=0

    _tmpSC="/tmp/.securityCheck"
    # Check for *.jwk files
    # shellcheck disable=SC2164
    test -d "${_scPath}" && _tmpPWD=$( pwd ) && cd "${_scPath}"
    find . -type f -name "${_patternToCheck}" > "${_tmpSC}"
    # shellcheck disable=SC2164
    test -d "${_scPath}" && cd "${_tmpPWD}"

    _numViolations=$( awk 'END{print NR}' "${_tmpSC}" )

    if test "${_numViolations}" -gt 0
    then
        if test "${SECURITY_CHECKS_STRICT}" = "true"
        then
            echo_red "SECURITY_CHECKS_FILENAME: ${_numViolations} files found matching file pattern ${_patternToCheck}"
        else
            echo_green "SECURITY_CHECKS_FILENAME: ${_numViolations} files found matching file pattern ${_patternToCheck}"
        fi

        cat_indent ${_tmpSC}

        _totalSecurityViolations=$(( _totalSecurityViolations + _numViolations ))
    fi

    export _totalSecurityViolations
}

###############################################################################
# sleep_at_most (num_seconds)
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
echo_header ()
{
  echo_bar

  while test -n "${1}"
  do
    _msg=${1} && shift
    echo "#    ${_msg}"
  done

  echo_bar
}


###############################################################################
# error_req_var (var)
#
# Check for the requirement, values of a variable and
# Echo a formatted list of variables and their value.  If the variable is
# empty, then, a sring of '---- empty ----' will be echoed
###############################################################################
echo_req_vars ()
{
    echo_red "# Variable (${_var}) is required."
}

###############################################################################
# echo_vars (var1, var2, ...)
#
# Check for the requirement, values of a variable and
# Echo a formatted list of variables and their value.
# If the variable is empty, then, '---- empty ----' will be echoed
# If the variable is found in env_vars file, then '(env_vars overridden)'
# If the varaible has a _REDACT=true, then '*** REDACTED ***'
###############################################################################
echo_vars ()
{
  while test -n "${1}"
  do
    _var=${1} && shift
    _val=$( get_value "${_var}" )

    # If the same var is found in env_vars, then we will print an
    # overridden message
    #
    grep -e "^${_var}=" "${STAGING_DIR}/env_vars" >/dev/null 2>/dev/null
    if test $? -eq 0
    then
        _overridden=" (env_vars overridden)"
    else
        _overridden=""
    fi

    # If the variable_REDACT is true, then we will print a
    # redaction message
    #
    _varRedact="${_var}_REDACT"
    _varRedact=$( get_value "${_varRedact}" )

    if test "${_varRedact}" = "true"
    then
      _val="*** REDACTED ***"
    fi

    printf "    %30s : %s %s\n" "${_var}" "${_val:---- empty ---}" "${_overridden}"

    # Find out if there is a _VALIDATION string
    #
    # var_VALIDATION must be of format "true|valid values|message"
    #
    _varValidation="${_var}_VALIDATION"
    _valValidation=$( get_value "${_varValidation}" )

    # Parse the validation value if it exists
    if test -n "${_valValidation}"
    then
      _validReq=$( echo "${_valValidation}" | sed  's/^\(.*\)|\(.*\)|\(.*\)$/\1/g' )
      _validVal=$( echo "${_valValidation}" | sed  's/^\(.*\)|\(.*\)|\(.*\)$/\2/g' )
      _validMsg=$( echo "${_valValidation}" | sed  's/^\(.*\)|\(.*\)|\(.*\)$/\3/g' )

      if test "${_validReq}" = "true" && test -z "${_val}"
      then
        # _validationFailed="true"
        test "${_validReq}" = "true" && echo_red "         Required: ${_var}"
        test -n "${_validVal}" && echo_red "     Valid Values: ${_validVal}"
        test -n "${_validMsg}" && echo_red "        More Info: ${_validMsg}"
      fi
    fi
  done
}

###############################################################################
# warn_unsafe_variables ()
#
# Provide hard warning about any varialbes starting with UNSAFE_
###############################################################################
warn_unsafe_variables ()
{

_unsafeValues="$(env | grep "^UNSAFE_" | awk -F'=' '{ print $2 }')"

if test -n "${_unsafeValues}"; then
    echo_red "################################################################################"
    echo_red "######################### WARNING - UNSAFE_ VARIABLES ##########################"
    echo_red "################################################################################"
    echo_red "#  The following UNSAFE variables are used.  Be aware of unintended consequences"
    echo_red "#  as it is considered unsafe to continue, especially in production deployments."
    echo_red ""

    for _unsafeVar in $(env | grep "^UNSAFE_" | sort | awk -F'=' '{ print $1 }') ; do
        _unsafeValue=$( get_value "${_unsafeVar}" )

        test -n "${_unsafeValue}" && echo_vars "${_unsafeVar}"
    done

    echo_red ""
    echo_red "################################################################################"
    echo_red ""
fi
}

###############################################################################
# source_container_env
#
# source and export all the CONTAINER_ENV variables
###############################################################################
source_container_env ()
{
    # shellcheck source=/dev/null
    if test -f "${CONTAINER_ENV}"
    then
        set -o allexport
        . "${CONTAINER_ENV}"
        set +o allexport
    fi
}

###############################################################################
# export_container_env (var1, var2, ...)
#
# Write the var passed to the CONTAINER_VAR for communication to further
# hooks
###############################################################################
export_container_env ()
{
    {
        echo ""
        echo_bar
        echo "# Following variables set by hook ${CALLING_HOOK}"
        echo_bar
    } >> "${CONTAINER_ENV}"

    while test -n "${1}"
    do
        _var=${1} && shift
        _val=$( get_value "${_var}" )

        echo "${_var}=${_val}" >> "${CONTAINER_ENV}"
    done

    source_container_env
}

###############################################################################
# main
###############################################################################
echo_green "----- Starting hook: ${CALLING_HOOK}"

source_container_env