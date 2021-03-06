#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

# shellcheck source=pingdatagovernancepap.lib.sh
test -f "${HOOKS_DIR}/pingdatagovernancepap.lib.sh" && . "${HOOKS_DIR}/pingdatagovernancepap.lib.sh"

# Move license to current location
# cp "${LICENSE_DIR}/${LICENSE_FILE_NAME}" .

# If the pre-82 start-server is present, setup has not yet been run.
# We need to determine the version of pingdatagovernancepap, construct
# the setup arguments accordingly, and select the version-appropriate start-server
# script.
if test -f "${SERVER_ROOT_DIR}"/bin/start-server-pre-82 ;
then
  _build_info_version=$(build_info_version <"${SERVER_ROOT_DIR}"/build-info.txt)
  echo_green "Beginning setup for build info version ${_build_info_version}"
  echo

  _setup_args_file="/tmp/setup-arguments.txt"

  check_external_url

  if is_version_ge "8.2.0.0" ;
  then

    if use_oidc_mode ;
    then
      echo_green "Setting up PAP in OpenID Connect mode..."
      echo
      echo "Using OIDC configuration endpoint: ${PING_OIDC_CONFIGURATION_ENDPOINT}"
      echo "This will override the --oidcBaseUrl value passed to setup."
      echo

      cat <<EOF >"${_setup_args_file}"
oidc
--oidcBaseUrl https://example.com
--clientId "${PING_CLIENT_ID}"
EOF

      check_external_url_oidc
    else
      echo_green "Setting up PAP in demo mode..."
      echo
      echo_yellow "WARNING: Demo mode uses insecure form-based authentication and "
      echo_yellow "should not be used in a production environment. If this is not "
      echo_yellow "what you want, redeploy the PAP using OpenID Connect mode."
      echo
      
      echo "demo" >"${_setup_args_file}"
    fi

    # Release 8.2.0.x added the ability to omit sensitive values from the
    # configuration generated by the setup tool.
    echo "--excludeSensitiveValues" >>"${_setup_args_file}"

    # Release 8.2.0.0-GA added an adminConnector for policy database backup
    # and healthcheck.
    if is_version_ge "8.2.0.0-RC" ;
    then
      echo "--adminPort 8444" >>"${_setup_args_file}"
    fi

  # Release 8.1.0.x added the ability to specify the DB admin credentials, but
  # but not through environment variables, so a workaround was needed
  # to provide Docker users that capability
  elif is_version_eq "8.1.0.0-GA" ;
  then
      cat <<EOF >"${_setup_args_file}"
demo
--dbAdminUsername "${PING_DB_ADMIN_USERNAME:-sa}"
--dbAdminPassword "${PING_DB_ADMIN_PASSWORD:-Symphonic2014!}"
EOF
  else
    echo "demo" > "${_setup_args_file}"
  fi

  # Command-line options common to all releases
  cat <<EOF >>"${_setup_args_file}"
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

  # Select the correct start-server based on the version
  if is_version_ge "8.2.0.0-EA" ;
  then
    rm "${SERVER_ROOT_DIR}"/bin/start-server-pre-82
  else
    mv "${SERVER_ROOT_DIR}"/bin/start-server-pre-82 \
      "${SERVER_ROOT_DIR}"/bin/start-server
  fi

  # Select the correct liveness check based on the build version
  if is_version_ge "8.2.0.0-RC" ;
  then
    rm "${BASE}"/liveness.sh-pre-82ga
  else
    mv "${BASE}"/liveness.sh-pre-82ga "${BASE}"/liveness.sh
  fi

fi

