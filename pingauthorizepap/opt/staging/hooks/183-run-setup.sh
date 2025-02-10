#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

# shellcheck source=./pingauthorizepap.lib.sh
test -f "${HOOKS_DIR}/pingauthorizepap.lib.sh" && . "${HOOKS_DIR}/pingauthorizepap.lib.sh"

_build_info_version=$(build_info_version < "${SERVER_ROOT_DIR}"/build-info.txt)
echo_green "Beginning setup for build info version ${_build_info_version}"
echo

_setup_args_file="/tmp/setup-arguments.txt"

check_external_url

if use_oidc_mode; then
    echo_green "Setting up PingAuthorize Policy Editor in OpenID Connect mode..."
    echo
    echo "Using OIDC configuration endpoint: ${PING_OIDC_CONFIGURATION_ENDPOINT}."
    echo "This will override the --oidcBaseUrl value passed to setup."
    echo

    cat << EOF > "${_setup_args_file}"
oidc
--oidcBaseUrl https://example.com
--clientId "${PING_CLIENT_ID}"
EOF

    check_external_url_oidc
else
    echo_green "Setting up PingAuthorize Policy Editor in demo mode..."
    echo
    echo_yellow "WARNING: Demo mode uses insecure form-based authentication and "
    echo_yellow "should not be used in a production environment. If this is not "
    echo_yellow "what you want, redeploy the Policy Editor using OpenID Connect mode."
    echo

    echo "demo" > "${_setup_args_file}"
fi

#
# Build certificate options. The PAP only supports providing
# keystore pin files starting from 9.1.0.0-GA. Older
# PAP versions should always generate self-signed certificates.
#
if is_version_gt "9.1.0.0-EA" || is_version_eq "9.1.0.0"; then
    certificateOptions=$(getCertificateOptions)
    _returnCode=${?}
    if test ${_returnCode} -ne 0; then
        echo_red "${certificateOptions}"
        container_failure 183 "Invalid certificate options"
    elif contains_uppercase "$CERTIFICATE_NICKNAME"; then
        echo_red "The CERTIFICATE_NICKNAME is $CERTIFICATE_NICKNAME, but the PingAuthorize "
        echo_red "Policy Editor does not support certificate names containing "
        echo_red "uppercase characters. Please use a different name when providing your "
        echo_red "server certificate."
        echo
        container_failure 183 "Invalid certificate nickname"
    else
        if test -n "${KEYSTORE_FILE}"; then
            echo_green "Setting up PingAuthorize Policy Editor to use a provided server certificate..."
            echo
            if test -n "${KEYSTORE_PIN_FILE}"; then
                echo "Using keystore pin file: ${KEYSTORE_PIN_FILE}."
                echo "This will override the --keystorePasswordFile value passed to setup."
                echo
            fi
        fi
    fi
else
    certificateOptions=--generateSelfSignedCertificate
fi

cat << EOF >> "${_setup_args_file}"
--excludeSensitiveValues
--adminPort "${PING_ADMIN_PORT:-8444}"
--licenseKeyFile "${LICENSE_DIR}/${LICENSE_FILE_NAME}"
--port ${HTTPS_PORT}
--hostname "${REST_API_HOSTNAME}"
${certificateOptions}
--ignoreWarnings
--decisionPointSharedSecret "${DECISION_POINT_SHARED_SECRET}"
EOF

echo "${ADDITIONAL_SETUP_ARGS}" >> "${_setup_args_file}"

# Run setup with the final argument list
xargs < "${_setup_args_file}" "${SERVER_ROOT_DIR}"/bin/setup

# Clean up the temporary file
rm -f "${_setup_args_file}"
