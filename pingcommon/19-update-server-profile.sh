#!/usr/bin/env sh
# shellcheck source=lib.sh
. "${BASE}/lib.sh"

if test "${SERVER_PROFILE_UPDATE}" = "true" ; then
    #
    # Remote updates
    #
    set -x
    cd "${SERVER_PROFILE_DIR}" || exit 99
    git pull
    # shellcheck disable=SC2035
    cp -af * "${STAGING_DIR}"
    # shellcheck disable=SC2164
    cd -

    #
    # Local updates
    #
    # shellcheck disable=SC2086
    apply_local_server_profile
fi