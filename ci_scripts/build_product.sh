#!/usr/bin/env bash
test -z "${1}" && exit 199
productToBuild="${1}"
shift
defaultOS=${1:-alpine}
shift
OSList=${*}

HERE=$(cd $(dirname "${0}");pwd)
if test -n "${CI_COMMIT_REF_NAME}" ;then
    . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
    # shellcheck source=./ci_tools.lib.sh
    . "${HERE}/ci_tools.lib.sh"
fi

exitCode=0
for OSToBuild in ${OSList:-alpine centos ubuntu} ; do
    "${HERE}/build_and_tag.sh" "${productToBuild}" "${OSToBuild}" "${defaultOS}" #"${versionsToBuild}"
    exitCode=${?}
    if test ${exitCode} -ne 0 ; then
        echo "Build break for ${productToBuild} on ${OSToBuild}"
        break
    fi
done

exit ${exitCode}