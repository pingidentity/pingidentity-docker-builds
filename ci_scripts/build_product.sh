#!/usr/bin/env sh
set -x
H=$( cd $( dirname ${0} ) ; pwd )

test -z "${1}" && exit 199

exitCode=0
for os in alpine ubuntu centos ; do
    "${H}/build_and_tag.sh" "${1}" "${os}"
    exitCode=${?}
    if test ${exitCode} -ne 0 ; then
        echo "Build break for ${1} on ${os}"
        break
    fi
done
exit ${exitCode}