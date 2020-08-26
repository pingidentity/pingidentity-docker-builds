#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- Gets secrets from secret management solution
#- * Hashicorp Vault
#

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=pingstate.lib.sh
. "${HOOKS_DIR}/pingstate.lib.sh"

_printVaultMessage ()
{
    printf "# %-20s : %s\n" "${1}" "${2}"
}

get_hashicorp_secrets()
{
    test -z "${VAULT_ADDR}" && _vaultErrMessage="Variable VAULT_ADDR is required to get secrets\n"

    #
    # Either a VAULT_TOKEN or VAULT_AUTH_USERNAMENAME/VAULT_AUTH_PASSWORD are required.  VAULT_TOKEN takes precedence
    if test -z "${VAULT_TOKEN}" ; then
        if test -n "${VAULT_AUTH_USERNAME}" ; then
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
        printf "Secrets Imported"

        for _secret in ${VAULT_SECRETS} ; do
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
            if test ${rc} -ne 0
            then
                printf "  %s (Error [%s] trying to get secret, most likely expired VAULT_TOKEN, permission issues or unknown secret.\n" "${_secret}" "${_httpResultCode}"
                continue
            fi

            echo "  ${_secret}"
            #
            # Defaults
            # - Do not link file
            # - Set permission to 0400 (read only by user)
            #
            _linkPath=""
            _permission="0400"

            #
            # Get meta-data items from keys
            #   _link - Specifices location of resulting file(s)
            #   _permission - Specifies the unix mode (i.e. 0400) to use on the file creation
            #
            for _keyName in $(jq -r '.data.data | keys[]' "${_tmpSFile}"); do
                case "${_keyName}" in
                    _link)
                        _linkPath=$(jq -r ".data.data[\"${_keyName}\"]" "${_tmpSFile}")
                        mkdir -p "${_linkPath}"
                        ;;
                    _permission)
                        _permission=$(jq -r ".data.data[\"${_keyName}\"]" "${_tmpSFile}")
                        ;;
                esac
            done

            for _keyName in $(jq -r '.data.data | keys[]' "${_tmpSFile}"); do
                case "${_keyName}" in
                    # Ignore keys for defined metadata
                    _link|_permission)
                        continue
                        ;;
                esac

                _secretFile="${SECRETS_DIR}/${_keyName}"

                #
                # Check to see if the secret file already exists.  If so, error as each
                # key must be unique.
                #
                if test -f "${_secretFile}"; then
                    echo "    ${_secretFile} (Ignoring: duplicate key)"
                    continue
                fi

                jq -r ".data.data[\"${_keyName}\"]" "${_tmpSFile}" > "${_secretFile}"

                chmod "${_permission}" "${_secretFile}"

                _writtenFile="${_secretFile}"
                _writtenKey="${_keyName}"
                #
                # Check to see if .b64 (encoded with base64)
                #
                case "${_keyName}" in
                    *.b64|*.base64)
                        _writtenKey="$(echo "${_keyName}" | sed -e 's/\.[^.]*64$//')"
                        _writtenFile="${SECRETS_DIR}/${_writtenKey}"
                        /bin/base64 -d "${_secretFile}" > "${_writtenFile}"
                        chmod "${_permission}" "${_writtenFile}"
                        ;;
                esac

                #
                # if _link provided, create a link to secret
                #
                if test -n "${_linkPath}"; then
                    _linkFile="${_linkPath}/${_writtenKey}"

                    if test -e "${_linkFile}" ; then
                        # saving the original file/dir/liink to timestamped copy
                        mv "${_linkFile}" "${_linkFile}.$(date '+%s')"
                    fi

                    ln -s "${_writtenFile}" "${_linkFile}"

                    echo "    ${_linkFile} -> ${_writtenFile}"
                else
                    echo "    ${_writtenFile}"
                fi
            done
        done

        rm -f "${_tmpSFile}"
    else
        echo_red "${_vaultErrMessage}"
    fi
}

#
# If the SECRETS_DIR doesn't exist
#
if test ! -d "${SECRETS_DIR}"; then
    echo_red "WARNING: SECRETS_DIR '${SECRETS_DIR}' not found!"

    # check the older legacy
    # location (/opt/staging/.sec) and set to that value along with providing
    # a warning message
    _legacySecretDir="${STAGING_DIR}/.sec"
    if test -d "${_legacySecretDir}"; then
        echo "         Old legacy secret location found.  Setting SECRETS_DIR=${_legacySecretDir}/"
        SECRETS_DIR="${_legacySecretDir}"
    else
        echo "         Important that the orchestration environment create a tmpfs for '${SECRETS_DIR}'"
        echo "         Using 'tmp/secrets' for now."
        SECRETS_DIR="/tmp/secrets"
        mkdir -p "${SECRETS_DIR}"
    fi

    export_container_env SECRETS_DIR
fi

#
# Check to see if hashicorp vault is used SECRETS are requested
#
if test "${VAULT_TYPE}" = "hashicorp" &&
   test -n "${VAULT_SECRETS}"; then
    get_hashicorp_secrets
fi

#
# TODO Would prefer the followig to be in it's own hook, after this point,
#      so for now, we don't want to exit this shell above.
#
add_state_info "${SECRETS_DIR}"

# Compare all the changes with previous/current state
echo
compare_state_info

# Flash the current state with current date/time
flash_state_info