#!/usr/bin/env bash
product=${1}
shift
osList=${*}
test -z "${osList}" && osList="alpine centos ubuntu"

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
for os in ${osList} ; do
    for version in ${versions} ; do      
        # test this version of this product
        if test ${notVersionless} = "true"; then
          _tag="${version}${notVersionless:+-${os}}-edge${ciTag:+-${ciTag}}"
        else
          _tag="${os}-${version}${ciTag:+-${ciTag}}"
        fi
        pull_and_tag "${FOUNDATION_REGISTRY}/${product}:${_tag}" "pingidentity/${product}:${_tag}"
        if test "${product}" = "pingdatasync" ; then
            pull_and_tag "${FOUNDATION_REGISTRY}/pingdirectory:${_tag}" "pingidentity/pingdirectory:${_tag}"
        fi
        for _test in ${product}/*.test.yml ; do
            env TAG=${_tag} docker-compose -f ./"${_test}" up --exit-code-from sut --abort-on-container-exit
            thisReturnCode=${?}
            test "${thisReturnCode}" -ne 0 && returnCode="${thisReturnCode}" && echo "
            ##################
            FAILED
            test       : ${_test}
            on         : ${_tag}
            ##################
            "
            env TAG=${_tag} docker-compose -f ./"${_test}" down
            test ${returnCode} -ne 0 && exit 1
        done
    done
done
exit ${returnCode}