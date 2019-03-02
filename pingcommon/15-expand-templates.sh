#!/usr/bin/env sh

# we check if there are templates that we have to run through env subst
# shellcheck disable=SC2044
for template in $( find "${STAGING_DIR}/" -type f -iname \*.subst ) ; do 
    envsubst < "${template}" > "${template%.*}"
done