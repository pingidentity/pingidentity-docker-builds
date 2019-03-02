#!/usr/bin/env sh

# Once both the GIT server-profile and the local server-profile have been merged
# then we can push that out to the instance
# this allows files provided locally to override those provided via the repo
if test -d "${STAGING_DIR}/instance" ; then
    cp -af "${STAGING_DIR}/instance" "${OUT_DIR}"
fi

