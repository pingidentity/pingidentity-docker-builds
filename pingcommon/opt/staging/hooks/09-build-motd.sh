#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#
#- Creates a message of the day (MOTD) file based on information provided by:
#- * Docker Variables
#- * Server-Profile motd file
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=./pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

motd_file="/etc/motd"
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

echo_bar >> "${motd_file}"

echo "Current ${motd_file}"
cat_indent "${motd_file}"

exit 0
