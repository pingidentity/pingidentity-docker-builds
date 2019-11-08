#!/usr/bin/env bash
product=${1}
defaultOS=alpine
os=${2:-${defaultOS}}

if test ! -z "${CI_COMMIT_REF_NAME}" ; then
  . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
  # shellcheck source=~/projects/devops/pingidentity-docker-builds/ci_scripts/ci_tools.lib.sh
  . ${HOME}/projects/devops/pingidentity-docker-builds/ci_scripts/ci_tools.lib.sh
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
if test  -f "${product}"/versions; then
  versions=$(grep -v "^#" "${product}"/versions)
  for version in ${versions}; do      
    #test this version of this product
    #TODO: test all the OSes. 
    preTag=${version}-${os}-edge
    pull_and_tag "${FOUNDATION_REGISTRY}/${product}:${preTag}-${ciTag}" "pingidentity/${product}:${preTag}"
    TAG=${version}-${os}-edge docker-compose -f ./"${product}"/build.test.yml up --exit-code-from sut
    thisReturnCode=${?}
    test "${thisReturnCode}" -ne 0 && returnCode="${thisReturnCode}" && echo "
    ##################
    THIS TEST FAILED
    return code: ${returnCode}
    ##################
    "
    TAG=${version}-${os}-edge docker-compose -f ./"${product}"/build.test.yml down
    ##TODO: add way to run compose from URLs. 
    # will have to add a file like test_urls with urls to raw github docker-compose-yamls. 
    # for f in ./"${product}"/tests/*.yaml ; do
    #   echo "running docker-compose up on ${f}"
    #   TAG=${version}-${os}-edge docker-compose -f $f up --exit-code-from sut
    #   returnCode=${?}
    #   TAG=${version}-${os}-edge docker-compose -f $f down
    #   test $returnCode -ne 0 && exit returnCode
    # done
  done
else
  pull_and_tag "${FOUNDATION_REGISTRY}/${product}:edge-${ciTag}" "pingidentity/${product}:edge"
  TAG=edge docker-compose -f ./"${product}"/build.test.yml up --exit-code-from sut
  returnCode=${?}
  TAG=edge docker-compose -f ./"${product}"/build.test.yml down
  test $returnCode -ne 0 && exit ${returnCode}
  # for f in ./"${product}"/tests/* ; do
  #   echo "running docker-compose up on ${f}"
  #   TAG=edge docker-compose -f $f up --exit-code-from sut
  #   returnCode=${?}
  #   TAG=edge docker-compose -f $f down
  #   test $returnCode -ne 0 && exit returnCode
  # done
fi

history | tail -100

exit ${returnCode}