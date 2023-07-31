#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- Creates a message of the day (MOTD) file based on information provided by:
#- * Docker Variables
#- * Github MOTD file from PingIdentity Devops Repo
#- * Server-Profile motd file
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=./pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

motd_file="/etc/motd"
motd_json_file="$(mktemp)"
current_date=$(date +%Y%m%d)

echo "
$(echo_bar)
                Ping Identity DevOps Docker Image

       Product: ${PING_PRODUCT}
       Version: ${IMAGE_VERSION}
   DevOps User: ${PING_IDENTITY_DEVOPS_USER}
      Hostname: ${HOST_NAME}
       Started: ${current_date}
$(echo_bar)" > "${motd_file}"

#
# Get a MOTD from the server profile if it is set
#
if test -f "${STAGING_DIR}/motd"; then
    cat "${STAGING_DIR}/motd" >> "${motd_file}"
fi

if test -z "${MOTD_URL}"; then
    echo "Not pulling MOTD since MOTD_URL is not set"
else
    motd_curl_result=$(curl -G -o "${motd_json_file}" -w '%{http_code}' "${MOTD_URL}" 2> /dev/null)

    if test "${motd_curl_result}" = "200"; then
        echo "Successfully downloaded MOTD from ${MOTD_URL}"
        jq_expr=".[] | select(.validFrom <= ${current_date} and .validTo >= ${current_date}) |
               \"\n---- SUBJECT: \" + .subject + \"\n\" +
                         (.message | join(\"\n\")) +
               \"\n\""
        image_name="$(toLower "${PING_PRODUCT}")"

        {
            jq -r "select (.devops != null) | .devops | ${jq_expr}" "${motd_json_file}"
            jq -r "select (.${image_name} != null) | .${image_name} | ${jq_expr}" "${motd_json_file}"
            echo
        } >> "${motd_file}"
    else
        echo_red "Unable to download MOTD from ${MOTD_URL}"
    fi
fi

echo_bar >> "${motd_file}"

echo "Current ${motd_file}"
cat_indent "${motd_file}"

exit 0
