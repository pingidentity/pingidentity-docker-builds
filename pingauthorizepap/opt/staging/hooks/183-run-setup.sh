#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

# shellcheck source=pingauthorizepap.lib.sh
test -f "${HOOKS_DIR}/pingauthorizepap.lib.sh" && . "${HOOKS_DIR}/pingauthorizepap.lib.sh"

# If the "delete-after-setup" file is present, setup has not yet been run.
# We need to determine the version of pingauthorizepap, construct
# the setup arguments accordingly, and select the version-appropriate start-server
# script.
if test -f "${SERVER_ROOT_DIR}"/delete-after-setup ;
then
  _build_info_version=$(build_info_version <"${SERVER_ROOT_DIR}"/build-info.txt)
  echo_green "Beginning setup for build info version ${_build_info_version}"
  echo

  _setup_args_file="/tmp/setup-arguments.txt"

  check_external_url

  if use_oidc_mode ;
  then
    echo_green "Setting up PingAuthorize Policy Editor in OpenID Connect mode..."
    echo
    echo "Using OIDC configuration endpoint: ${PING_OIDC_CONFIGURATION_ENDPOINT}."
    echo "This will override the --oidcBaseUrl value passed to setup."
    echo

    cat <<EOF >"${_setup_args_file}"
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
    
    echo "demo" >"${_setup_args_file}"
  fi

  cat <<EOF >>"${_setup_args_file}"
--excludeSensitiveValues
--adminPort 8444
--licenseKeyFile "${LICENSE_DIR}/${LICENSE_FILE_NAME}"
--port ${HTTPS_PORT}
--hostname "${REST_API_HOSTNAME}"
--generateSelfSignedCertificate
--ignoreWarnings
--decisionPointSharedSecret "${DECISION_POINT_SHARED_SECRET}"
EOF

  echo "${ADDITIONAL_SETUP_ARGS}" >>"${_setup_args_file}"

  # Run setup with the final argument list
  xargs <"${_setup_args_file}" "${SERVER_ROOT_DIR}"/bin/setup

  # Clean up the temporary file
  rm -f "${_setup_args_file}"

  rm "${SERVER_ROOT_DIR}"/delete-after-setup

fi

