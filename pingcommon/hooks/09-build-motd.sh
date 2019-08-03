#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- Creates a message of the day (MOTD) file based on information prvoded by:
#- * Docker Varibbles
#- * Github MOTD file from PingIdentity Devops Repo
#- * Server-Profile motd file
#
${VERBOSE} && set -x

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

_motdFile="/etc/motd"
_motdJsonFile="/tmp/motd.json"
_currentDate=$(date +%Y%m%d)

echo "
##################################################################################
                Ping Identity DevOps Docker Image

       Version: ${IMAGE_VERSION}
   DevOps User: ${PING_IDENTITY_DEVOPS_USER}
      Hostname: ${HOSTNAME}
       Started: $(date)
##################################################################################" > "${_motdFile}"

#
# Get a MOTD from the server profile if it is set
#
if test -f "${STAGING_DIR}/motd" ; then
    cat "${STAGING_DIR}/motd" >> "${_motdFile}"
fi

if test -z "${MOTD_URL}" ; then
    echo "Not pulling MOTD since MOTD_URL is not set"
else
    _motdCurlResult=$(curl -G -o "${_motdJsonFile}" -w '%{http_code}' "${MOTD_URL}" 2> /dev/null)

    if test ${_motdCurlResult} -eq 200 ; then
        echo "Successfully downloaded MOTD from ${MOTD_URL}"
        _jqExpr=".[] | select(.validFrom <= ${_currentDate} and .validTo >= ${_currentDate}) |
               \"\n---- SUBJECT: \" + .subject + \"\n\" +
                         (.message | join(\"\n\")) +
               \"\n\""
        _imageName=$(echo ${IMAGE_VERSION} | sed 's/-.*//')


        cat ${_motdJsonFile} | jq -r ".devops | ${_jqExpr}" >> "${_motdFile}"
        cat ${_motdJsonFile} | jq -r ".${_imageName} | ${_jqExpr}" >> "${_motdFile}"
    else
        echo_red "Unable to download MOTD from ${MOTD_URL}"
    fi
fi

echo "##################################################################################" >> "${_motdFile}"

echo "Current ${_motdFile}"
cat_indent "${_motdFile}"
