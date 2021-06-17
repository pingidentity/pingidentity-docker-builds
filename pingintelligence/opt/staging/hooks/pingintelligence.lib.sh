#!/usr/bin/env sh
test "${VERBOSE}" = "true" && set -x

CLI="${SERVER_ROOT_DIR}/bin/cli.sh"
PING_INTELLIGENCE_DEFAULT_ADMIN_USER="admin"
PING_INTELLIGENCE_DEFAULT_ADMIN_PASSWORD="admin"

pi_get_config() {
    test -z "${1}" && return 1
    conf_file="${SERVER_ROOT_DIR}/config/${1}.conf"
    test -f "${conf_file}" || return 2
    awk -F= '$0~/^'"${2}"'=/{print $2}' "${conf_file}"
    exit ${?}
}

pi_add_api() {
    test -z "${1}" && return 1
    echo_green "Adding API defined in ${1}"
    "${CLI}" add_api -u "${PING_INTELLIGENCE_ADMIN_USER}" -p "${PING_INTELLIGENCE_ADMIN_PASSWORD}" "${1}"
    returnCode=${?}

    if test ${returnCode} -eq 0; then
        echo_green "Successfully added API defined in ${1}"
    else
        echo_red "ERROR adding API defined in ${1}"
    fi
    return ${returnCode}
}

pi_update_password() {
    printf "%s\n%s\n%s\n" "${PING_INTELLIGENCE_DEFAULT_ADMIN_PASSWORD}" "${PING_INTELLIGENCE_ADMIN_PASSWORD}" "${PING_INTELLIGENCE_ADMIN_PASSWORD}" | "${CLI}" -u "${PING_INTELLIGENCE_ADMIN_USER}" update_password
    return ${?}
}

pi_obfuscate_keys() {
    "${CLI}" -u "${PING_INTELLIGENCE_DEFAULT_ADMIN_USER}" -p "${PING_INTELLIGENCE_DEFAULT_ADMIN_PASSWORD}" obfuscate_keys -y
    return ${?}
}

pi_get_status() {
    "${CLI}" status | awk -F: '$1~/status/{s=$2;gsub(/ /,"",s); print s}'
    return ${?}
}

isASERunning() {
    test "$(pi_get_status)" = "started"
    return ${?}
}
