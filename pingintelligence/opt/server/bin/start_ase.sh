#!/usr/bin/env sh
test "${VERBOSE}" = "true" && set -x

# Copyright 2024 Ping Identity Corporation.
# Ping Identity reserves all rights in the program as delivered. Unauthorized use, copying,
# modification, reverse engineering, disassembling, attempt to discover any source code or
# underlying ideas or algorithms, creating other works from it, and distribution of this
# program is strictly prohibited. The program or any portion thereof may not be used or
# reproduced in any form whatsoever except as provided by a license without the written
# consent of Ping Identity. A license under Ping Identity's rights in the program may be
# available directly from Ping Identity.

log() {
    echo "${*}" >> "${CONTROLLER_LOG}"
}

umask 027

CONTROLLER_BINARY="${SERVER_ROOT_DIR}/lib/controller"
CONTROLLER_LOG_DIR="${SERVER_ROOT_DIR}/logs/"
CONTROLLER_LOG="${SERVER_ROOT_DIR}/logs/controller.log"
CONTROLLER_CONFIG_DIR="${SERVER_ROOT_DIR}"

export CONTROLLER_ROOT_DIR="${SERVER_ROOT_DIR}"
# shellcheck disable=SC1091
. "${SERVER_ROOT_DIR}/bin/env_var.sh"

test -d "${CONTROLLER_LOG_DIR}" || mkdir "${CONTROLLER_LOG_DIR}"
CONTROLLER_LOG_DIR_STATUS=${?}
# shellcheck disable=SC2086
if test ${CONTROLLER_LOG_DIR_STATUS} -ne 0; then
    echo "Could not create '${CONTROLLER_LOG_DIR}'"
    exit 1
fi

# res=$("${CONTROLLER_BINARY}" "${CONTROLLER_CONFIG_DIR}" api ping)
# CONTROLLER_ALIVE_STATUS=${?}
# if test ${CONTROLLER_ALIVE_STATUS} -eq 0 && test "${res}" = "pong"; then
#     echo "Another instance of API Security Enforcer is already running"
#     exit 1
# fi

# I'm not 100% certain this is advisable yet
# TODO: make a definitive recommendation for relocating core dump pattern ( within container vs without )
# I am fairly confident that it must be done from outside to preserve container confinement but it will be vetted
# disabling the POSIX warning because EUID is set on centos
# shellcheck disable=SC2039,SC3028
if test -n "${EUID}" && test ${EUID} -eq 0; then
    (echo "${SERVER_ROOT_DIR}/logs/core_dump/core_%e_%P_%t" > /proc/sys/kernel/core_pattern) 2> /dev/null
fi

# check if timezone is set to utc in ase.conf and export TZ variable
var_tz_val=$(awk -F= '$0~/^timezone/{print tolower($2)}' "${SERVER_ROOT_DIR}/config/ase.conf")
test ${?} -ne 0 && echo "Could not parse ASE configuration file" && exit 7
case "${var_tz_val}" in
    utc)
        log "Starting ASE in UTC timezone"
        export TZ="Etc/UTC"
        ;;
    local)
        log "Starting ASE in local timezone"
        ;;
    *)
        echo_red "Timezone [${var_tz_val}] is not an allowed value for timezone in ase.conf."
        exit 1
        ;;
esac

"${CONTROLLER_BINARY}" "${CONTROLLER_CONFIG_DIR}" management start >> "${CONTROLLER_LOG}"
