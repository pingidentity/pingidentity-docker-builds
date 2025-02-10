#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

# Check if OIDC-related environment variables have been provided.
use_oidc_mode() {
    ! test -z "${PING_OIDC_CONFIGURATION_ENDPOINT}" && ! test -z "${PING_CLIENT_ID}"
}

# Check if PING_EXTERNAL_BASE_URL is defined and warn if not
check_external_url() {
    if test -z "${PING_EXTERNAL_BASE_URL}"; then
        echo_yellow "WARNING: PING_EXTERNAL_BASE_URL is undefined."
    fi
}

# Make a simple check to make sure that PING_EXTERNAL_BASE_URL doesn't use
# localhost, which is unlikely to be useful in OIDC mode
check_external_url_oidc() {
    if ! test "${PING_EXTERNAL_BASE_URL}" = "${PING_EXTERNAL_BASE_URL#localhost}" ||
        ! test "${PING_EXTERNAL_BASE_URL}" = "${PING_EXTERNAL_BASE_URL#127.0.0.1}"; then
        echo_yellow "WARNING: PING_EXTERNAL_BASE_URL uses a hostname that may not be externally resolvable."
        echo_yellow "This may cause the PAP to generate an unusable OIDC redirect URI."
        echo_yellow "Current PING_EXTERNAL_BASE_URL value: ${PING_EXTERNAL_BASE_URL}"
    fi
}

# Check if the provided argument contains uppercase letters.
contains_uppercase() {
    test "$(echo "${1}" | awk \
        'BEGIN {found=1}
$0~/[A-Z]/ {found=0}
END {printf "%d",found}')" -eq 0
}
