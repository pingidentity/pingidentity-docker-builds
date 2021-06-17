#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build
#
# Common functions used with secrets
#

###############################################################################
# get_hashicorp_secrets
#
# Using following variables, pull secretes from a hashicorp vault:
#  - VAULT_ADDR
#  - VAULT_TOKEN
#  - VAULT_AUTH_USERNAME
#  - VAULT_AUTH_PASSWORD
#
###############################################################################
get_hashicorp_secrets() {
    test -z "${VAULT_ADDR}" && _vaultErrMessage="Variable VAULT_ADDR is required to get secrets\n"

    #
    # Either a VAULT_TOKEN or VAULT_AUTH_USERNAME/VAULT_AUTH_PASSWORD are required.  VAULT_TOKEN takes precedence
    if test -z "${VAULT_TOKEN}"; then
        if test -n "${VAULT_AUTH_USERNAME}"; then
            # If the VAULT_TOKEN is not set, then use the VAULT_AUTH_USERNAME/VAULT_AUTH_PASSWORD to get a token
            echo "Getting VAULT_TOKEN using login with '${VAULT_AUTH_USERNAME}/************'"
            _tmpTokenJson=$(mktemp)

            _httpResultCode=$(
                curl \
                    --silent \
                    --show-error \
                    --write-out '%{http_code}' \
                    --location \
                    --connect-timeout 2 \
                    --retry 6 \
                    --retry-max-time 30 \
                    --retry-connrefused \
                    --retry-delay 3 \
                    --request POST \
                    --header "Content-Type: application/json" \
                    --data "{\"password\":\"${VAULT_AUTH_PASSWORD}\"}" \
                    "${VAULT_ADDR}/v1/auth/userpass/login/${VAULT_AUTH_USERNAME}" \
                    --output "${_tmpTokenJson}"
            )

            #
            # If the curl returns a non-200, emit a message that the authentication wouldn't work
            #
            if test "${_httpResultCode}" != "200"; then
                _vaultErrMessage="${_vaultErrMessage}Error (${_httpResultCode}) trying to authenticate with user '${VAULT_AUTH_USERNAME}'.\n"
                _vaultErrMessage="${_vaultErrMessage}      Most likely missing or invalid VAULT_AUTH_USERNAME/VAULT_AUTH_PASSWORD.\n"
            else
                VAULT_TOKEN=$(jq -r '.auth.client_token' "${_tmpTokenJson}")
            fi

            rm -f "${_tmpTokenJson}"
        else
            _vaultErrMessage="${_vaultErrMessage}Variable VAULT_TOKEN or VAULT_AUTH_USERNAME/VAULT_AUTH_PASSWORD are required to access vault"
        fi
    fi

    if test -z "${_vaultErrMessage}"; then
        _tmpSFile=$(mktemp)

        echo ""
        printf "Pulling secrets using VAULT_ADDR..."

        for _secret in ${VAULT_SECRETS}; do
            echo
            #
            # Attempt to get the secret based on the VAULT_ADDR and VAULT_TOKEN passed
            #
            _curl \
                --header "X-Vault-Token: ${VAULT_TOKEN}" \
                "${VAULT_ADDR}/v1/secret/data${_secret}" \
                --output "${_tmpSFile}"

            #
            # If the curl returns a non-zero, emit a message that the secret couldn't be obtained
            #
            rc=${?}
            if test ${rc} -ne 0; then
                printf "  %s (Error [%s] trying to get secret, most likely expired VAULT_TOKEN, permission issues or unknown secret.\n" "${_secret}" "${_httpResultCode}"
                continue
            fi

            _secretFile="${SECRETS_DIR}/$(basename "${_secret}").json"

            #
            # Check to see if the secret file already exists.  If so, error as each
            # secret name must be unique.
            #
            if test -f "${_secretFile}"; then
                echo_red "  ${_secret} (ignoring: duplicate secret found - possibly from hashicorp injector)"
            else
                echo "  ${_secret}"

                #
                # Copy the raw json contents to a {secret-name}.json file
                #
                jq '.data.data' < "${_tmpSFile}" > "${_secretFile}"
            fi
        done

        rm -f "${_tmpSFile}"
    else
        echo_red "${_vaultErrMessage}"
    fi

    #
    # Clear out VAULT_TOKEN
    #
    unset VAULT_TOKEN
}

###############################################################################
# process_secrets_env_json
#
# process all files ending in env.json to .env files
###############################################################################
process_secrets_env_json() {
    #
    # Processing all *.env.json files
    #
    for _secretJson in "${SECRETS_DIR}"/*.env.json; do
        test -f "${_secretJson}" || break # handle if no *.env.json files found

        # remove the .json extension
        _secretEnvFile="$(echo "${_secretJson}" | sed -e 's/\.json$//')"

        echo "  ${_secretJson}"
        echo "     --> ${_secretEnvFile} (env property file)"

        for key in $(jq -r "keys | flatten[]" "${_secretJson}"); do
            echo "$key=$(jq ".$key" "${_secretJson}")" >> "${_secretEnvFile}"
        done

        mv "${_secretJson}" "${_secretJson}".PROCESSED
    done
}

###############################################################################
# process_secrets_json
#
# process all files ending in .json
#
# Keys in each .json will be written to a file with the value in its contents
###############################################################################
process_secrets_json() {
    #
    # Processing all *.json files
    #
    for _secretJson in "${SECRETS_DIR}"/*.json; do
        test -f "${_secretJson}" || break # handle if no *.json files found

        _permission="0400"

        echo "  ${_secretJson}"

        for _keyName in $(jq -r 'keys[]' "${_secretJson}"); do
            _secretFile="${SECRETS_DIR}/${_keyName}"

            #
            # Check to see if the secret file already exists.  If so, error as each
            # key must be unique.
            #
            if test -f "${_secretFile}"; then
                echo_red "     ${_secretFile} (ignoring: duplicate key)"
                continue
            fi

            echo "     --> ${_secretFile}"

            jq -r ".[\"${_keyName}\"]" "${_secretJson}" > "${_secretFile}"

            chmod "${_permission}" "${_secretFile}"

            _writtenFile="${_secretFile}"
            _writtenKey="${_keyName}"
            #
            # Check to see if .b64 (encoded with base64)
            #
            case "${_keyName}" in
                *.b64 | *.base64)
                    _writtenKey="$(echo "${_keyName}" | sed -e 's/\.[^.]*64$//')"
                    _writtenFile="${SECRETS_DIR}/${_writtenKey}"
                    /bin/base64 -d "${_secretFile}" > "${_writtenFile}"
                    chmod "${_permission}" "${_writtenFile}"
                    echo "     --> ${_writtenFile} (base64 decoded)"
                    ;;
            esac
        done

        mv "${_secretJson}" "${_secretJson}".PROCESSED
    done
}

###############################################################################
# process_secrets
#
# 1. Pulls secrets if VAULT_TYPE/VAULT_SECRETS provided
#
# 2. Process .env.json files
#
# 3. Process .json files
#
###############################################################################
process_secrets() {
    #
    # Check to see if hashicorp vault is used SECRETS are requested
    #
    if test "${VAULT_TYPE}" = "hashicorp" &&
        test -n "${VAULT_SECRETS}"; then
        get_hashicorp_secrets
    fi

    echo "Processing secrets in SECRETS_DIR (if any)..."

    process_secrets_env_json

    process_secrets_json
}
