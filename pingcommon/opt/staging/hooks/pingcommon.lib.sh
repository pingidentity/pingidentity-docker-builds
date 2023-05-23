#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build
#
# Common functions used throughout Docker Image Hooks
#
test "${VERBOSE}" = "true" && set -x

# capture the calling hook so it can be echoed later on
CALLING_HOOK=${0}

# check for devops file in docker secrets location
# shellcheck disable=SC1090
test -f "/run/secrets/${PING_IDENTITY_DEVOPS_FILE}" && . "/run/secrets/${PING_IDENTITY_DEVOPS_FILE}"

#
#
#  Some extremely basic functions to make life with variables a bit easier
#
#
toLower() {
    printf "%s" "${*}" | tr '[:upper:]' '[:lower:]'
}

toLowerVar() {
    toLower "$(eval printf "%s" \$"${1}")"
}

lowerVar() {
    eval "${1}=$(toLowerVar "${1}")"
}

toUpper() {
    printf "%s" "${*}" | tr '[:lower:]' '[:upper:]'
}

toUpperVar() {
    toUpper "$(eval printf "%s" \$"${1}")"
}

upperVar() {
    eval "${1}=$(toUpperVar "${1}")"
}

#
# Common wrapper for curl to make reliable calls
# NOTICE: This function expects --output to be passed in as function arguments,
# otherwise the test and return will fail, as HTTP_RESULT_CODE with contain the curl output
#
_curl() {
    #Build curl options in $@
    set -- --get \
        --silent \
        --show-error \
        --write-out "%{http_code}" \
        --location \
        --connect-timeout 2 \
        --retry 6 \
        --retry-max-time 30 \
        --retry-delay 3 \
        "${@}"

    # CentOS and RHEL curl does not support the retry on connection refused option
    if ! isOS "centos" && ! isOS "rhel"; then
        set -- --retry-connrefused "${@}"
    fi

    HTTP_RESULT_CODE=$(curl "${@}")
    # Shellcheck complains this variable isn't used, but it are exported below
    # shellcheck disable=SC2034
    EXIT_CODE=${?}
    test "${HTTP_RESULT_CODE}" = "200"
    return ${?}
}

#
# Stable function to retrieve OS information
#
parseOSRelease() {
    test -n "${1}" && awk '$0~/^'"${1}"'=/ {split($1,id,"="); gsub(/"/,"",id[2]); print id[2];}' < /etc/os-release 2> /dev/null
}

# The OS ID is all lowercase
getOSID() {
    parseOSRelease ID
}

getOSVersion() {
    parseOSRelease VERSION
}

# The name is often pretty-printed
getOSName() {
    parseOSRelease NAME
}

isOS() {
    _targetOS="${1}"
    _currentOS="$(getOSID)"
    test -n "${_targetOS}" && test "${_targetOS}" = "${_currentOS}"
    return ${?}
}

#
# Read the host name directly from the /proc filesystem
# this avoid implementation differences between distros
# the RHEL shim in particular doesn't ship the hostname cli
#
getHostName() {
    cat /proc/sys/kernel/hostname
}

getDomainName() {
    _result=$(cat /proc/sys/kernel/domainname)
    if test "$(toLower "${_result}")" = "(none)"; then
        _result=""
    fi
    echo "${_result}"
}

getSemanticImageVersion() {
    major=$(echo "${PING_PRODUCT_VERSION}" | awk -F"." '{ print $1 }')
    minor=$(echo "${PING_PRODUCT_VERSION}" | awk -F"." '{ print $2 }')
    patch=$(echo "${PING_PRODUCT_VERSION}" | awk -F"." '{ print $3 }')
}

# send desired semantic version to be compared to image version.
#   example: IMAGE_VERSION=10.1.0
#   test $( isImageVersionGtEq 10.0.0 ) -eq 0 && echo "current image is greater or equal"
isImageVersionGtEq() {
    getSemanticImageVersion
    aVersion=${1}
    aMajor=$(echo "${aVersion}" | awk -F"." '{ print $1 }')
    aMinor=$(echo "${aVersion}" | awk -F"." '{ print $2 }')
    aPatch=$(echo "${aVersion}" | awk -F"." '{ print $3 }')

    test "${aMajor}" -gt "${major}" && echo 1 && return
    test "${aMajor}" -eq "${major}" && test "${aMinor}" -gt "${minor}" && echo 1 && return
    test "${aMajor}" -eq "${major}" && test "${aMinor}" -eq "${minor}" && test "${aPatch}" -gt "${patch}" && echo 1 && return

    echo 0
}

#check for newline for multi-line colored echo
nl='
'
echo_color() {
    _color="$(toLower "${1}")"
    shift
    case "${_color}" in
        red) _colorCode='\033[0;31m' ;;
        green) _colorCode='\033[0;32m' ;;
        yellow) _colorCode='\033[0;33m' ;;
    esac
    _endColor='\033[0m'
    case "${1}" in
        *$nl*)
            if test "${COLORIZE_LOGS}" = "true"; then
                while IFS= read -r _eachline; do
                    printf "%b%s%b\n" "${_colorCode}" "${_eachline}" "${_endColor}"
                done << MLEOF
${*}
MLEOF
            else
                while IFS= read -r _eachline; do
                    printf "%s\n" "${_eachline}"
                done << MLEOF
${*}
MLEOF
            fi
            ;;
        *)
            if test "${COLORIZE_LOGS}" = "true"; then
                printf "%b%s%b\n" "${_colorCode}" "${*}" "${_endColor}"
            else
                printf "%s\n" "${*}"
            fi
            ;;
    esac
}

###############################################################################
# echo_red (message)
#
# Prints a message in the color red
###############################################################################
echo_red() {
    echo_color red "${*}"
}

###############################################################################
# echo_green (message)
#
# Prints a message in the color green
###############################################################################
echo_green() {
    echo_color green "${*}"
}

###############################################################################
# echo_yellow (message)
#
# Prints a message in the color yellow
###############################################################################
echo_yellow() {
    echo_color yellow "${*}"
}

###############################################################################
# echo_bar ()
#
# Echos a bar of 80 hash marks
###############################################################################
echo_bar() {
    printf "################################################################################\n"
}

###############################################################################
# cat_indent (file)
#
# cat a file to stdout and indent 4 spaces
###############################################################################
cat_indent() {
    test -f "${1}" && sed 's/^/    /' < "${1}"
}

###############################################################################
# cat_comment (file)
#
# cat a file to stdout and indent with a comment '# '
###############################################################################
cat_comment() {
    test -f "${1}" && sed 's/^/# /' < "${1}"
}

###############################################################################
# run_if_present (script)
#
# runs a script, if the script is present
###############################################################################
run_if_present() {
    _runFile=${1}

    _commandSet="sh"
    ${VERBOSE} && _commandSet="${_commandSet} -x"
    if test -f "${_runFile}"; then
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
container_failure() {
    _exitCode=${1} && shift

    if test "$(toLower "${UNSAFE_CONTINUE_ON_ERROR}")" = "true"; then
        echo_red "$(
            cat << EOF
################################################################################
################################### WARNING ####################################
################################################################################
#  ERROR (${_exitCode}): $*
################################################################################
#
#  Container would normally fail at this point, however the
#  variable UNSAFE_CONTINUE_ON_ERROR is set to '${UNSAFE_CONTINUE_ON_ERROR}'
#
#  Container will continue with unknown potential side-effects
#  and consequences!!!
#
################################################################################
EOF
        )"
    else
        echo_red "CONTAINER FAILURE: $*"

        _osID="$(getOSID)"
        case "${_osID}" in
            redhat | fedora | centos)
                kill -n 15 1
                test $? -ne 0 && kill -n 9 1
                ;;
            *)
                kill -15 1
                test $? -ne 0 && kill -9 1
                ;;
        esac
        #Container should be dead by now, so this exit command should not run.
        exit "${_exitCode}"
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
die_on_error() {
    _errorCode=${?}
    _exitCode=${1} && shift

    if test ${_errorCode} -ne 0; then
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
run_hook() {
    _hookScript="$1"
    _hookExit=$(echo "${_hookScript}" | sed 's/^\([0-9]*\).*$/\1/g')

    test -z "${_hookExit}" && _hookExit=99

    run_if_present "${HOOKS_DIR}/${_hookScript}.pre"
    die_on_error "${_hookExit}" "Error running ${_hookScript}.pre" || exit ${?}

    run_if_present "${HOOKS_DIR}/${_hookScript}"
    die_on_error "${_hookExit}" "Error running ${_hookScript}" || exit ${?}

    run_if_present "${HOOKS_DIR}/${_hookScript}.post"
    die_on_error "${_hookExit}" "Error running ${_hookScript}.post" || exit ${?}
}

###############################################################################
# apply_local_server_profile ()
#
# apply the locally provided files via IN_DIR to the staging directory
# We do this on every startup such that updates to the IN_DIR contents apply
# on container restart
###############################################################################
apply_local_server_profile() {
    if test -n "${IN_DIR}" && test -n "$(ls -A "${IN_DIR}" 2> /dev/null)"; then
        echo "copying local IN_DIR files (${IN_DIR}) to STAGING_DIR (${STAGING_DIR})"
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
copy_files() {
    SRC="$1"
    DST="$2"

    if ! test -e "${DST}"; then
        echo "copy_files - dst dir (${DST}) does not exist - will create it"
        mkdir -p "${DST}"
    elif ! test -d "${DST}"; then
        echo "Error: copy_files - dst (${DST}) must be a directory"
        exit 1
    fi

    (cd "${SRC}" && find . -type f -exec cp -fL --parents '{}' "${DST}" \;)
}

###############################################################################
# security_filename_check (path)
#
#   path - Where to find any files following pattern
#   pattern - pattern to search for (i.e. *.jwk)
#
# check files in the path for potential security issues based on pattern passed
###############################################################################
security_filename_check() {
    _scPath="${1}"
    _patternToCheck="${2}"

    test -z "${TOTAL_SECURITY_VIOLATIONS}" && TOTAL_SECURITY_VIOLATIONS=0

    _tmpSC="/tmp/.securityCheck"
    # Check for *.jwk files
    # shellcheck disable=SC2164
    test -d "${_scPath}" && _tmpPWD=$(pwd) && cd "${_scPath}"
    find . -type f -name "${_patternToCheck}" > "${_tmpSC}"
    # shellcheck disable=SC2164
    test -d "${_scPath}" && cd "${_tmpPWD}"

    _numViolations=$(awk 'END{print NR}' "${_tmpSC}")

    if test "${_numViolations}" -gt 0; then
        if test "${SECURITY_CHECKS_STRICT}" = "true"; then
            echo_red "SECURITY_CHECKS_FILENAME: ${_numViolations} files found matching file pattern ${_patternToCheck}"
        else
            echo_green "SECURITY_CHECKS_FILENAME: ${_numViolations} files found matching file pattern ${_patternToCheck}"
        fi

        cat_indent ${_tmpSC}

        TOTAL_SECURITY_VIOLATIONS=$((TOTAL_SECURITY_VIOLATIONS + _numViolations))
    fi

    export TOTAL_SECURITY_VIOLATIONS
}

now() {
    date '+%s'
}

###############################################################################
# sleep_at_most (num_seconds)
#
# Sleep at least one second and at most the indicated duration and
# echos a message
###############################################################################
sleep_at_most() {
    _max=$1
    _modulus=$((_max - 1))
    if test "${FIPS_MODE_ON}" = "true"; then
        _random_num=$(now)
    else
        _random_num=$(awk 'BEGIN { srand(); print int(rand()*32768) }' /dev/null)
    fi
    _result=$((_random_num % _modulus))
    _duration=$((_result + 1))
    echo "Sleeping ${_duration} seconds (max: ${_max})..."

    sleep ${_duration}
}

###############################################################################
# waitForDns (timeout_seconds host1 hostn)
#
# This function will wait for the container IP to resolve from list of hosts
###############################################################################
waitForDns() {
    echo "INFO: waiting for dns propagation"

    _timeout=0
    _timeout_limit=${1}
    shift
    _hostnames=$*
    _count=0
    _count_limit=3

    while test "$_timeout" -lt "$_timeout_limit"; do
        for hostname in $_hostnames; do
            getent ahosts "${hostname}" | awk '{print $1}' | sort -u | grep "$(hostname -i)" > /dev/null
            if test $? -eq 0; then
                hostname_found=true
            fi
        done
        if test "${hostname_found}" = "true"; then
            unset hostname_found
            _count=$((_count + 1))
            if test "$_count" -ge "$_count_limit"; then
                echo "INFO: Waiting for verification of IP resolution from hostname(s)"
                break
            fi
        else
            _count=0
        fi
        _timeout=$((_timeout + 2))
        sleep 2
    done
    if test "$_timeout" -ge "$_timeout_limit"; then
        echo "ERROR: Timed out waiting for dns"
        exit 1
    fi
    echo "INFO: IP successfully resolves from hostname(s)"
}

###############################################################################
# get_value (variable, checkFile)
#
# Get the value of a variable passed, preserving any spaces.
# If the provided variable isn't set, and the value of the second parameter
# checkFile is true, then the corresponding file variable will be checked.
# For example if "get_value ADMIN_USER_PASSWORD true" is called and the
# ADMIN_USER_PASSWORD variable isn't set, then the ADMIN_USER_PASSWORD_FILE
# variable will be checked. If the file variable is set, the value will be
# read from the corresponding file.
###############################################################################
get_value() {
    # the following will preserve spaces in the printf
    IFS=""
    value="$(eval printf '%s' "\${${1}}")"
    checkFile="$(toLower "${2}")"
    if test -z "${value}" && test "${checkFile}" = "true"; then
        fileVar="${1}_FILE"
        file="$(eval printf '%s' "\${${fileVar}}")"
        if test -n "${file}"; then
            value="$(cat "${file}")"
        fi
    fi
    printf '%s' "${value}"
    unset IFS
}

###############################################################################
# echo_header (line1, line2, ...)
#
# Echo a header, with each line passed on separate lines
###############################################################################
echo_header() {
    echo_bar

    while test -n "${1}"; do
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
# empty, then, a string of '---- empty ----' will be echoed
###############################################################################
echo_req_vars() {
    echo_red "# Variable (${_var}) is required."
}

###############################################################################
# echo_vars (var1, var2, ...)
#
# Check for the requirement, values of a variable and
# Echo a formatted list of variables and their value.
# If the variable is empty, then, '---- empty ----' will be echoed
# If the variable is found in env_vars file, then '(env_vars overridden)'
# If the variable has a _REDACT=true, or if the _redactAll variable is set
# to true, then '*** REDACTED ***'
###############################################################################
echo_vars() {
    while test -n "${1}"; do
        _var=${1} && shift
        _val=$(get_value "${_var}")

        # If the same var is found in env_vars, then we will print an
        # overridden message
        #
        grep -e "^${_var}=" "${STAGING_DIR}/env_vars" > /dev/null 2> /dev/null
        if test $? -eq 0; then
            _overridden=" (env_vars overridden)"
        else
            _overridden=""
        fi

        # If the variable_REDACT is true, then we will print a
        # redaction message
        #
        _varRedact="${_var}_REDACT"
        _varRedact=$(get_value "${_varRedact}")

        if test "${_varRedact}" = "true" || test "${_redactAll}" = "true"; then
            _val="*** REDACTED ***"
        fi

        printf "    %30s : %s %s\n" "${_var}" "${_val:---- empty ---}" "${_overridden}"

        # Find out if there is a _VALIDATION string
        #
        # var_VALIDATION must be of format "true|valid values|message"
        #
        _varValidation="${_var}_VALIDATION"
        _valValidation=$(get_value "${_varValidation}")

        # Parse the validation value if it exists
        if test -n "${_valValidation}"; then
            _validReq=$(echo "${_valValidation}" | sed 's/^\(.*\)|\(.*\)|\(.*\)$/\1/g')
            _validVal=$(echo "${_valValidation}" | sed 's/^\(.*\)|\(.*\)|\(.*\)$/\2/g')
            _validMsg=$(echo "${_valValidation}" | sed 's/^\(.*\)|\(.*\)|\(.*\)$/\3/g')

            if test "${_validReq}" = "true" && test -z "${_val}"; then
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
# Provide hard warning about any variables starting with UNSAFE_
###############################################################################
warn_unsafe_variables() {

    _unsafeValues="$(env | grep "^UNSAFE_" | awk -F'=' '{ print $2 }')"

    if test -n "${_unsafeValues}"; then
        echo_red "################################################################################"
        echo_red "######################### WARNING - UNSAFE_ VARIABLES ##########################"
        echo_red "################################################################################"
        echo_red "#  The following UNSAFE variables are used.  Be aware of unintended consequences"
        echo_red "#  as it is considered unsafe to continue, especially in production deployments."
        echo_red ""

        for _unsafeVar in $(env | grep "^UNSAFE_" | sort | awk -F'=' '{ print $1 }'); do
            _unsafeValue=$(get_value "${_unsafeVar}")

            test -n "${_unsafeValue}" && echo_vars "${_unsafeVar}"
        done

        echo_red ""
        echo_red "################################################################################"
        echo_red ""
    fi
}

###############################################################################
# warn_deprecated_variables ()
#
# Provide a warning about any deprecated variables
###############################################################################
warn_deprecated_variables() {
    # Add any new deprecated variables to this file in the pingcommon image.
    _deprecatedVarsJson="/opt/staging/deprecated-variables.json"
    if ! test -f "${_deprecatedVarsJson}"; then
        return 0
    fi

    _deprecatedHeaderPrinted=false
    # Read variable names from the json file
    for _deprecatedVar in $(jq -r '.[] | .name' "${_deprecatedVarsJson}"); do
        _deprecatedValue=$(get_value "${_deprecatedVar}")
        if test -n "${_deprecatedValue}"; then
            if test "${_deprecatedHeaderPrinted}" != "true"; then
                echo_yellow "################################################################################"
                echo_yellow "################################################################################"
                echo_yellow "###################### WARNING - DEPRECATED VARIABLES ##########################"
                echo_yellow "#  The following deprecated variables were found. These variables may be removed"
                echo_yellow "#  in a future release."
                echo_yellow ""
                _deprecatedHeaderPrinted=true
            fi
            # Don't print values of sensitive variables
            _sensitive=$(jq -r ".[] | select(.name==\"${_deprecatedVar}\") | .sensitive" "${_deprecatedVarsJson}")
            if test "${_sensitive}" = "true"; then
                _redactAll=true
            else
                _redactAll=false
            fi
            echo_vars "${_deprecatedVar}"
            # Print a specific message for variables that have provided one
            _deprecatedVarMessage=$(jq -r ".[] | select(.name==\"${_deprecatedVar}\") | .message" "${_deprecatedVarsJson}")
            if test -n "${_deprecatedVarMessage}" && test "${_deprecatedVarMessage}" != "null"; then
                echo_yellow "# ${_deprecatedVarMessage}"
            fi
        fi
    done
    if test "${_deprecatedHeaderPrinted}" = "true"; then
        echo_yellow ""
        echo_yellow "################################################################################"
        echo_yellow ""
    fi
    _redactAll=false
}

###############################################################################
# print_variable_warnings ()
#
# Print warnings for deprecated variables and variables starting with _UNSAFE
###############################################################################
print_variable_warnings() {
    warn_deprecated_variables
    warn_unsafe_variables
}

###############################################################################
# source_container_env
#
# source and export all the CONTAINER_ENV variables
###############################################################################
source_container_env() {
    # shellcheck source=/dev/null
    if test -f "${CONTAINER_ENV}"; then
        set -o allexport
        . "${CONTAINER_ENV}"
        set +o allexport
    fi
}

###############################################################################
# source_secret_envs
#
# source and export all ${SECRETS_DIR}/*.env files (including subdirectories)
###############################################################################
source_secret_envs() {
    if test -d "${SECRETS_DIR}"; then
        find "${SECRETS_DIR}" -type f -name '*.env' -print > /tmp/_envFile
        while IFS= read -r _envFile; do
            # Check current .env file for CRLF
            # Exit if found
            test_crlf "${_envFile}"
            die_on_error 11 ""

            # Otherwise, continue
            set -o allexport
            # shellcheck source=/dev/null
            . "${_envFile}"
            set +o allexport
        done < /tmp/_envFile
        rm -f /tmp/_envFile
    fi
}

###############################################################################
# export_container_env (var1, var2, ...)
#
# Write the var passed to the CONTAINER_VAR for communication to further
# hooks
###############################################################################
export_container_env() {
    {
        echo ""
        echo_bar
        echo "# Following variables set by hook ${CALLING_HOOK}"
        echo_bar
    } >> "${CONTAINER_ENV}"

    while test -n "${1}"; do
        _var=${1} && shift
        _val=$(get_value "${_var}")

        echo "${_var}=${_val}" >> "${CONTAINER_ENV}"
    done

    source_container_env
}

###############################################################################
# test_crlf (file)
#
# Scan the passed file for CRLF characters
###############################################################################
test_crlf() {
    _testCRLFFile="${1}"

    # Test for file being passed
    # shellcheck disable=SC2164
    if test ! -f "${_testCRLFFile}"; then
        echo_red "${_testCRLFFile} is not a file.  Exiting."
        return 1
    fi

    # See if file has CRLF (^M or \r, depending on the tool used)
    # grep uses \r notation
    # "$(printf '<val>')" is needed to successfully find CRLF using redhats version of grep
    grep -q "$(printf '\r')" "${_testCRLFFile}"

    # grep returns 0 if pattern is matched, and returns 1 if not.
    if test $? -eq 0; then
        echo_red "${_testCRLFFile} contains CRLF line endings which may produce undefined behavior. Exiting."
        # Return non-zero to calling program
        return 11
    fi

    return 0
}

###############################################################################
# contains (str1, str2)
#
# Check if str1 contains str2
###############################################################################
contains() {
    string="$1"
    substring="$2"
    if test "${string#*"${substring}"}" != "${string}"; then
        # substring is in string
        return 0
    else
        # substring is not in string
        return 1
    fi
}

###############################################################################
# contains_ignore_case (str1, str2)
#
# Check if str1 contains str2, ignoring case
###############################################################################
contains_ignore_case() {
    stringLower="$(toLower "$1")"
    substringLower="$(toLower "$2")"
    contains "${stringLower}" "${substringLower}"
    return ${?}
}

###############################################################################
# clean_staging_file (filename)
#
# Processes an individual file for clean_staging_dir. If the staging manifest
# exists, the specified filename is a file, and the filename is not included
# in the manifest, then it will be deleted.
###############################################################################
clean_staging_file() {
    if test -f "${STAGING_MANIFEST}" && ! grep -Fxq "${1}" "${STAGING_MANIFEST}"; then
        if test -f "${1}"; then
            rm "${1}"
        elif test -d "${1}"; then
            rmdir "${1}"
        fi
    fi
}

###############################################################################
# clean_staging_dir
#
# Clean the /opt/staging directory. This method deletes any files under
# /opt/staging that are not listed in the manifest file
# /opt/staging-manifest.txt, which is generated when the image is built.
# If that manifest file does not exist, then no files will be deleted.
# This method is used to clean the /opt/staging directory before copying a
# local server profile or pulling a remote profile in.
###############################################################################
clean_staging_dir() {
    find "${STAGING_DIR}" | awk '{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--] }' | while read -r file; do clean_staging_file "${file}"; done
}

###############################################################################
# make_bar
#
# Generate a string composed of the repetition of a single character a
# number of times
# $1: the character to repeat
# $2: the number of times the character is to be repeated
###############################################################################
make_bar() {
    _char="${1}"
    _length=${2}
    _result=""
    while test "${_length}" -gt 0; do
        _result="${_result}${_char}"
        _length=$((_length - 1))
    done
    printf "%s" "${_result}"
}

###############################################################################
# show_libs_ver
#
# prints out library versions on the standard output
# $1: optionally, pass the "log4j" string to print only library versions
#     relevant to log4j
###############################################################################
show_libs_ver() {
    _tmpDir="$(mktemp -d)"
    test -z "${_tmpDir}" && exit 1
    case "${1}" in
        log4j)
            find "${SERVER_ROOT_DIR}" -type f \( -name \*log4j\*.jar -o -name disruptor\*.jar \) > "${_tmpDir}"/mf.list 2> /dev/null
            ;;
        *)
            find "${SERVER_ROOT_DIR}" -type f -name \*.jar > "${_tmpDir}"/mf.list 2> /dev/null
            ;;
    esac
    _mfDir="META-INF"
    _mf="${_mfDir}/MANIFEST.MF"
    _pomProps="pom.properties"
    _props="${_mfDir}/*/${_pomProps}"
    printf "%-60s| %-61s| %-7s\n" "LOCATION" "FILE" "VERSION"
    printf "%-60s|%-62s|%-8s\n" "$(make_bar _ 60)" "$(make_bar _ 62)" "$(make_bar _ 8)"
    while read -r j; do
        unzip -oqud "${_tmpDir}" "${j}" "${_mfDir}/*"
        if test -d "${_tmpDir}/${_mfDir}" && test -f "${_tmpDir}/${_mf}"; then
            for _keyword in Bundle-Version Specification-Version Implementation-Version; do
                _ver=$(awk -F: '$1~/^'${_keyword}'$/{gsub(/ */,"",$2);print $2;exit(0);}' "${_tmpDir}/${_mf}")
                test -n "${_ver}" && break
            done
        fi
        if test -z "${_ver}"; then
            # Optimistically expect the first properties file to be the right one
            _file="$(find "${_tmpDir}/${_mfDir}" -type f -name "${_pomProps}" -print -quit 2> /dev/null)"
            test -n "${_file}" && _ver="$(awk -F= '$1~/version/{print $2;exit(0);}' "${_file}")"
        fi
        if test -z "${_ver}"; then
            # No version could be found so we'll compute the MD5 hash for the file as a fallthrough versioning mechanism
            _ver="MD5:$(md5sum "${j}" | awk '{print $1;exit(0);}')"
        fi
        printf "%-60s| %-61s| %-6s\n" "$(dirname "${j}")" "$(basename "${j}")" "${_ver:-N/A}"
        rm -rf "${_tmpDir:?}/${_mfDir}"
        # explicitly unset temporary variable values to avoid issues on next loop
        _ver=""
        _file=""
    done < "${_tmpDir}"/mf.list
    rm -rf "${_tmpDir}"
}

###############################################################################
# main
###############################################################################
echo_green "----- Starting hook: ${CALLING_HOOK}"

source_container_env
source_secret_envs
