#!/usr/bin/env sh
${VERBOSE} && set -x

# shellcheck source=/dev/null
if test -f "${STAGING_DIR}/env_vars" ; then
    set -o allexport
    . "${STAGING_DIR}/env_vars"
    set +o allexport
fi

# we check if there are templates that we have to run through env subst
# shellcheck disable=SC2044
for template in $( find "${STAGING_DIR}/" -type f -iname \*.subst ) ; do 
    envsubst < "${template}" > "${template%.*}"
done