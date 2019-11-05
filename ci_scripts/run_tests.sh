#!/usr/bin/env sh
set -x

product=${1}

echo testing "${product}"
if test  -f "${product}"/versions; then
  versions=$(grep -v "^#" "${product}"/versions)
  for version in ${versions}; do      
    #test this version of this product
    TAG=${version}-alpine-edge docker-compose -f ./"${product}"/build.test.yml up --exit-code-from sut
    returnCode=${?}
    TAG=${version}-alpine-edge docker-compose -f ./"${product}"/build.test.yml down
  done
else
  TAG=edge docker-compose -f ./"${product}"/build.test.yml up --exit-code-from sut
  returnCode=${?}
  TAG=edge docker-compose -f ./"${product}"/build.test.yml down
  #if it relates to a sprint, tag it as latest overall
fi

exit ${returnCode}