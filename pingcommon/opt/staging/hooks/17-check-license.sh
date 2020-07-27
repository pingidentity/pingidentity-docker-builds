#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- Check for license file
#- - If LICENSE_FILE found make call to check-license api unless MUTE_LICENSE_VERIFICATION set to true
#- - If LICENSE_FILE not found and PING_IDENTITY_DEVOPS_USER and PING_IDENTITY_DEVOPS_KEY defined
#-   make call to obtain a license from license server
#
#  TODO - Should probably add more mechanisms to pull from other
#         locations (i.e. vaults/secrets)
#
${VERBOSE} && set -x

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

LICENSE_FILE="${LICENSE_DIR}/${LICENSE_FILE_NAME}"
_licenseAPI="https://license.pingidentity.com/devops/license"
_checkLicenceAPI="https://license.pingidentity.com/devops/check-license"

if test -f "${LICENSE_FILE}"
then
    _licenseID=$(awk 'BEGIN{FS="="}$1~/^ID/{print $2}' "${LICENSE_FILE}")

    case "${MUTE_LICENSE_VERIFICATION}" in
        TRUE|true|YES|yes|Y|y)
            echo "Opting out of license verfication due to MUTE_LICENSE_VERIFICATION=${MUTE_LICENSE_VERIFICATION}"
            ;;
        *)
            echo "Verifying license with a network query to https://license.pingidentity.com."
            echo "You may opt out of this setting environment variable 'MUTE_LICENSE_VERFICATION=yes'."
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
   if test ! -z "${PING_IDENTITY_DEVOPS_USER}" && test ! -z "${PING_IDENTITY_DEVOPS_KEY}"
   then
        ##################################################################
        # Let's get the license from the license server
        ##################################################################
        if ! test -z "${LICENSE_SHORT_NAME}" && ! test -z "${LICENSE_VERSION}"
        then
            echo "Pulling evaluation license from Ping Identity for:"
            echo "   Prod License: ${LICENSE_SHORT_NAME} - v${LICENSE_VERSION}"
            echo "    DevOps User: ${PING_IDENTITY_DEVOPS_USER}..."

            _curl \
                --header "product: ${LICENSE_SHORT_NAME}" \
                --header "version: ${LICENSE_VERSION}" \
                --header "devops-user: ${PING_IDENTITY_DEVOPS_USER}" \
                --header "devops-key: ${PING_IDENTITY_DEVOPS_KEY}" \
                --header "devops-app: ${IMAGE_VERSION}" \
                --header "devops-purpose: get-license" \
                "${_licenseAPI}" \
                --output "${LICENSE_FILE}"
            #
            # Just testing the http code isn't sufficient, curl will return http 200 if it
            # can retrieve the file even if it can't actually write the file to disk. We
            # also need to capture & test the curl return code.
            #
            rc=${?}
            if test ${rc} -eq 0
            then
                echo ""
                echo "Successfully pulled evaluation license from Ping Identity"
                test "${PING_DEBUG}" = "true" && cat_indent "${LICENSE_FILE}"
                echo ""

                case "${PING_IDENTITY_ACCEPT_EULA}" in
                    YES|yes|Y|y)
                        ;;
                    *)
                    container_failure 17 "You must accept the EULA by providing the environment variable PING_IDENTITY_ACCEPT_EULA=YES"
                    ;;
                esac

                licenseFound="true"
            else
                _licenseError=$( jq -r ".error" "${LICENSE_FILE}" 2> /dev/null)

                if test -z "${_licenseError}" || "${_licenseError}" = "null"
                then
                    _licenseError="Error (${_httpResultCode}).  Please contact devops_program@pingidentity.com with this log."
                fi

                echo ""
                echo "Unable to download evaluation license:"
                echo "         Reason: ${_licenseError}"

                rm -f "${LICENSE_FILE}"
            fi
        else
            echo "Unable to determine LICENSE_SHORT_NAME (${LICENSE_SHORT_NAME}) or LICENSE_VERSION (${LICENSE_VERSION})"
        fi
    fi
fi

if test "${licenseFound}" != "true"
then
    echo_red "
##################################################################################
############################        ALERT        #################################
##################################################################################
#
# No Ping Identity License File (${LICENSE_FILE_NAME}) was found in the server profile.
# No Ping Identity DevOps evaluation license downloaded.
#
#
# More info on obtaining your DevOps User and Key can be found at:
#      https://pingidentity-devops.gitbook.io/devops/prod-license
#
##################################################################################"
    container_failure 17 "License File absent"
fi
