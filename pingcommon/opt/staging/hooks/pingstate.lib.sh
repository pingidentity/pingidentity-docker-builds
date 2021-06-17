#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build
#
# Common functions used throughout Docker Image Hooks
#

# Location to hold container state information
STATE_DIR="${OUT_DIR}/container-state"

###############################################################################
# add_state_info (file or directory or 'environment_variables')
#
# Create state_info for the passed environment_variables/file/directory.
# Will result in a set of sha256sum hash values if directory of all files
# within that directory recursively.  For files, the file contents will be copied.
# If the passed value is 'environment_variables', the current environment
# variables will be captured.
###############################################################################
add_state_info() {
    _sourceInfo="${1}"

    # echo "#############################"
    # echo "# Add State Info for ${_sourceInfo}"
    # echo "#############################"

    _stateDir="${STATE_DIR}/current"
    mkdir -p "${_stateDir}"

    # Creates a file substituting slashes (/) with underscores (_) and removes leading underscore
    _hashFile="$(echo "${_sourceInfo}" | sed 's/\//_/g' | sed 's/^_//')"

    if test "${_sourceInfo}" = "environment_variables"; then
        env | sort | grep -v "^HOST_NAME=" > "${_stateDir}/${_hashFile}"
    elif test -f "${_sourceInfo}"; then
        cp "${_sourceInfo}" "${_stateDir}/${_hashFile}.file"
    elif test -d "${_sourceInfo}"; then
        find "${_sourceInfo}" -type f -print | sort | xargs sha256sum > "${_stateDir}/${_hashFile}.hash"
    else
        echo "Unable to add state info for unknown resource '${_sourceInfo}'"
    fi
}

###############################################################################
# flash_state_info ()
#
# Flash the current state to the STATE_DIR based on the current datetime.
###############################################################################
flash_state_info() {
    _stateId=$(date +"%Y%m%d%H%M%S%Z")

    # echo "#############################"
    # echo "# Flash Current State into ${_stateId}"
    # echo "#############################"

    if test -d "${STATE_DIR}/current"; then
        mv "${STATE_DIR}/current" "${STATE_DIR}/${_stateId}"
    fi
}

###############################################################################
# compare_state_info ()
#
# Compares the current state with the previous state (if available).  echos out
# differences as well as setting a variable '_stateChanged' which will reflect
# how many state differences were found.
###############################################################################
compare_state_info() {
    _tmpStateDir=$(mktemp -d)
    _currState="current"
    #Find all directories in STATE_DIR that are not named "current", remove leading '.' and '/', and return the ??last in the list??
    _prevState=$(find "${STATE_DIR}" -type d -maxdepth 1 ! -name current ! -path . | sed 's/.//;s/\///' | tail -1)

    _stateChanged=0

    if test ! -d "${STATE_DIR}/current" || test -z "${_prevState}" || test ! -d "${STATE_DIR}/${_prevState}"; then
        echo "No previous state to compare."
    else
        echo "#############################"
        echo "# Comparing current state with previous (${_prevState})"
        echo "#############################"
        {
            ls "${STATE_DIR}/${_prevState}"
            ls "${STATE_DIR}/${_currState}"
        } > "${_tmpStateDir}/state.files"
        sort -u "${_tmpStateDir}/state.files" > "${_tmpStateDir}/state.files.sorted"

        while IFS= read -r _fileToDiff; do
            if test ! -f "${STATE_DIR}/${_prevState}/${_fileToDiff}"; then
                echo "New file found in current container - ${STATE_DIR}/${_prevState}/${_fileToDiff}"
                continue
            fi
            if test ! -f "${STATE_DIR}/${_currState}/${_fileToDiff}"; then
                echo "File removed in current container - ${STATE_DIR}/${_currState}/${_fileToDiff}"
                continue
            fi

            diff -U 0 -L PREVIOUS -L CURRENT "${STATE_DIR}/${_prevState}/${_fileToDiff}" "${STATE_DIR}/${_currState}/${_fileToDiff}" > "${_tmpStateDir}/state.diff"
            _diffRC=$?
            _stateChanged=$((_stateChanged + _diffRC))

            if test "${_diffRC}" = "1"; then
                echo ""
                echo "Changes made to: ${_fileToDiff}"
                echo "=================================="
                grep "^[-|+]" < "${_tmpStateDir}/state.diff"
                #awk -F' ' '{ print substr($1,1,1) $2 }' USE THIS IF WE WANT TO REMOVE THE HASH
            fi
        done < "${_tmpStateDir}/state.files.sorted"
    fi

    # If state has changed, emit different error messages for different products
    if test "${_stateChanged}" != 0; then
        case ${PING_PRODUCT} in
            PingDirectory) ;;

            *)
                echo_red "**************************************"
                echo_red " Changes have been detected from a previous start of the container."
                echo_red " Restart will continue with these changes being ignored."
                echo_red ""
                echo_red " To start fresh, remove/clear out the persistent storage (i.e. /opt/out)."
                echo_red "**************************************"
                ;;
        esac
    fi

    rm -rf "${_tmpStateDir}"
}
