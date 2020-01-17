#!/usr/bin/env bash
product=${1}
defaultOS=${3:-alpine}
os=${2:-${defaultOS}}

HERE=$(cd $(dirname ${0});pwd)
if test ! -z "${CI_COMMIT_REF_NAME}" ; then
  . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
  # shellcheck source=~/projects/devops/pingidentity-docker-builds/ci_scripts/ci_tools.lib.sh
  . ${HERE}/ci_tools.lib.sh
fi


pull_and_tag(){
    if test "${FOUNDATION_REGISTRY}" = "gcr.io/ping-identity" ; then
        docker pull "${1}"
        docker tag "${1}" "${2}"
    fi
    #image is expected to be there if not on CI
}
returnCode=0
echo testing "${product}"
versions="edge"
if test  -f "${product}"/versions; then
  versions=$(grep -v "^#" "${product}"/versions)
  notVersionless="false"
fi
for version in ${versions} ; do      
    # test this version of this product
    _tag="${version}${notVersionless:+-${os}}-${ciTag}"
    docker pull "${FOUNDATION_REGISTRY}/${product}:${_tag}"
    env TAG=${_tag} docker-compose -f ./"${product}"/build.test.yml up --exit-code-from sut
    thisReturnCode=${?}
    test "${thisReturnCode}" -ne 0 && returnCode="${thisReturnCode}" && echo "
    ##################
    THIS TEST FAILED
    return code: ${returnCode}
    ##################
    "
    env TAG=${_tag} docker-compose -f ./"${product}"/build.test.yml down
done
exit ${returnCode}