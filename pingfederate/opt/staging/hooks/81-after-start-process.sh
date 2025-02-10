#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# check if admin password is to be changed by looking for an 'initial' password
if test -f "${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}" || test "$(toLower "${CREATE_INITIAL_ADMIN_USER}")" = "true"; then
    run_hook 83-configure-admin.sh
fi

# check for bulk config import file
if test -f "${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}"; then
    run_hook 85-import-configuration.sh
fi
