#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- Check for license file
#- - If LICENSE_FILE found make call to check-license api unless MUTE_LICENSE_VERIFICATION set to true
#- - If LICENSE_FILE not found and PING_IDENTITY_DEVOPS_USER and PING_IDENTITY_DEVOPS_KEY defined
#-   make call to obtain a license from license server
#
#  TODO - Should probably add more mechanisms to pull from other locations (i.e. vaults/secrets)
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=./pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

#check if license directory exists, and if not then creates. Likely only matters for containers which were using old LICENSE_DIR value.
if test ! -d "${LICENSE_DIR}"; then
    mkdir -p "${LICENSE_DIR}"
fi

LICENSE_FILE="${LICENSE_DIR}/${LICENSE_FILE_NAME}"
_licenseAPI="https://license.pingidentity.com/devops/license"
_checkLicenceAPI="https://license.pingidentity.com/devops/check-license"

if test -f "${LICENSE_FILE}"; then
    _licenseID=$(awk 'BEGIN{FS="="}$1~/^ID/{print $2}' "${LICENSE_FILE}")

    case "${MUTE_LICENSE_VERIFICATION}" in
        TRUE | true | YES | yes | Y | y)
            echo "Opting out of license verification due to MUTE_LICENSE_VERIFICATION=${MUTE_LICENSE_VERIFICATION}"
            ;;
        *)
            echo "Verifying license with a network query to https://license.pingidentity.com."
            echo "You may opt out of this setting environment variable 'MUTE_LICENSE_VERIFICATION=yes'."
            echo "   License File: ${LICENSE_FILE}"
            echo "        License: ${_licenseID}"

            _curl \
                --header "license-id: ${_licenseID}" \
                --header "devops-app: ${IMAGE_VERSION}" \
                --header "devops-purpose: check-license" \
                "${_checkLicenceAPI}" \
                --output "/tmp/check-license.json"
            ;;
    esac

    licenseFound="true"
else
    #alert user there is no license file found at $LICENSE_FILE directory
    echo "A license file was not provided at the expected location: ${LICENSE_DIR}/${LICENSE_FILE_NAME}"
    if test ! -z "${PING_IDENTITY_DEVOPS_USER}" && test ! -z "${PING_IDENTITY_DEVOPS_KEY}"; then
        echo "We will now attempt to retrieve an evaluation license."
        ##################################################################
        # Let's get the license from the license server
        ##################################################################
        if ! test -z "${LICENSE_SHORT_NAME}" && ! test -z "${LICENSE_VERSION}"; then
            echo "Pulling evaluation license from Ping Identity for:"
            echo "   Prod License: ${LICENSE_SHORT_NAME} - v${LICENSE_VERSION}"
            echo "    DevOps User: ${PING_IDENTITY_DEVOPS_USER}..."

            _resultCode=99
            _retries=4
            while test ${_retries} -gt 0; do
                _retries=$((_retries - 1))
                _curl \
                    --header "product: ${LICENSE_SHORT_NAME}" \
                    --header "version: ${LICENSE_VERSION}" \
                    --header "devops-user: ${PING_IDENTITY_DEVOPS_USER}" \
                    --header "devops-key: ${PING_IDENTITY_DEVOPS_KEY}" \
                    --header "devops-app: ${IMAGE_VERSION}" \
                    --header "devops-purpose: get-license" \
                    "${_licenseAPI}" \
                    --output "${LICENSE_FILE}"

                test "${HTTP_RESULT_CODE}" = "200" && test "${EXIT_CODE}" = "0" && break
            done
            #
            # Just testing the http code isn't sufficient, curl will return http 200 if it
            # can retrieve the file even if it can't actually write the file to disk. We
            # also need to capture & test the curl exit code.
            #
            if test "${HTTP_RESULT_CODE}" = "200" && test "${EXIT_CODE}" = "0"; then
                echo ""
                echo "Successfully pulled evaluation license from Ping Identity"
                test "${PING_DEBUG}" = "true" && cat_indent "${LICENSE_FILE}"
                echo ""

                case $(toLower "${PING_IDENTITY_ACCEPT_EULA}") in
                    yes | y) ;;

                    *)
                        container_failure 17 "You must accept the EULA by providing the environment variable PING_IDENTITY_ACCEPT_EULA=YES"
                        ;;
                esac

                licenseFound="true"
            else
                _licenseError=$(jq -r ".error" "${LICENSE_FILE}" 2> /dev/null)

                if test -z "${_licenseError}" || test "${_licenseError}" = "null"; then
                    _licenseError="Error (http code: ${HTTP_RESULT_CODE} exit code: ${EXIT_CODE}). Ping Identity customers can create a case in the [Ping Identity Support Portal](https://support.pingidentity.com/s/)
 with this log. Non-Ping Identity customers can use the [PingDevOps Community](https://support.pingidentity.com/s/topic/0TO1W000000IF30WAG/pingdevops) for questions."
                fi

                echo ""
                echo "Unable to download evaluation license:"
                echo "         Reason: ${_licenseError}"

                rm -f "${LICENSE_FILE}"
            fi
        else
            echo_red "Unable to determine LICENSE_SHORT_NAME (${LICENSE_SHORT_NAME}) or LICENSE_VERSION (${LICENSE_VERSION}) for ${PING_PRODUCT}"
        fi
    else
        echo_red "No credentials were provided to retrieve an evaluation license."
    fi
fi

if test "${licenseFound}" != "true"; then
    echo_red "
##################################################################################
############################        ALERT        #################################
##################################################################################
#
# License File could not be found at the expected location
# ${LICENSE_DIR}/${LICENSE_FILE_NAME}
# An evaluation license could not be obtained from PingIdentity either.
#
#
# More info on obtaining your DevOps User and Key can be found at:
#      https://devops.pingidentity.com/how-to/devopsRegistration/
#
##################################################################################"
    container_failure 17 "License File absent"
fi
