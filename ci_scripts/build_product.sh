#!/usr/bin/env bash
test -z "${1}" && exit 199
productToBuild="${1}"
shift
defaultOS=${1:-alpine}
shift
OSList=${*}

if test -n "${CI_COMMIT_REF_NAME}" ;then
    . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
    HERE=$(cd $(dirname "${0}");pwd)
    # shellcheck source=./ci_tools.lib.sh
    . "${HERE}/ci_tools.lib.sh"
fi

exitCode=0
for OSToBuild in ${OSList:-alpine centos ubuntu} ; do
    "${HERE}/build_and_tag.sh" "${productToBuild}" "${defaultOS}" "${OSToBuild}" #"${versionsToBuild}"
    exitCode=${?}
    if test ${exitCode} -ne 0 ; then
        echo "Build break for ${productToBuild} on ${OSToBuild}"
        break
    fi
done

if test -z "${HERE}" ; then
    history | tail -100
fi

exit ${exitCode}