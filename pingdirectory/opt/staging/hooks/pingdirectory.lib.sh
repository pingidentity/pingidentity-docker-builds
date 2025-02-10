#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# Append ldif template files in the pd.profile to the variables-ignore.txt file
appendTemplatesToVariablesIgnore() {
    find "${PD_PROFILE}/ldif" -maxdepth 1 -mindepth 1 -type d 2> /dev/null | while read -r _ldifDir; do
        find "${_ldifDir}" -type f -iname \*.template 2> /dev/null | while read -r _template; do
            # Add the generated ldif file to the profile's variables-ignore.txt file, to avoid
            # the potential memory overhead of variable substitution on a large file.
            _generatedLdifFilename="${_template%.*}.ldif"
            _generatedLdifBasename=$(basename "${_generatedLdifFilename}")
            _backendID=$(basename "${_ldifDir}")
            echo "ldif/${_backendID}/${_generatedLdifBasename}" >> "${PD_PROFILE}/variables-ignore.txt"
        done
    done
}

setLoadBalancingAlgorithms() {
    test -z "${LOAD_BALANCING_ALGORITHM_NAMES}" && return 0
    echo "Setting load-balancing algorithm names for PingDirectory"

    # Use positional arguments to build dsconfig args for setting the load-balancing algorithms
    set -- --instance-name "${INSTANCE_NAME}"
    _names="${LOAD_BALANCING_ALGORITHM_NAMES}"
    _iter=""
    if test -n "${_names}"; then
        while test "${_names}" != "${_iter}"; do
            # Extract the algorithm name from start of string up to ';' delimiter.
            _iter=${_names%%;*}
            # Delete the first algorithm name and the ';' from LOAD_BALANCING_ALGORITHM_NAMES
            _names="${_names#"${_iter}";}"
            # Add the argument for the extracted algorithm name
            set -- "$@" --add "load-balancing-algorithm-name:${_iter}"
        done
    fi

    dsconfig set-server-instance-prop --no-prompt --quiet \
        "$@"
    _setAlgorithmsResult=$?

    if test ${_setAlgorithmsResult} -ne 0; then
        echo_red "Failed to configure load-balancing-algorithm-name values on the server instance"
        return ${_setAlgorithmsResult}
    fi
    echo "Load-balancing algorithm names configured successfully"
    return 0
}
