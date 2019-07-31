#!/usr/bin/env sh
set -x -e

product=${1}

echo testing "${product}"
if test  -f "${product}"/versions; then
  versions=$(grep -v "^#" "${product}"/versions)
  for version in ${versions}; do      
    #test this version of this product
    TAG=${version}-edge docker-compose -f ./"${product}"/build.test.yml up --exit-code-from sut
    TAG=${version}-edge docker-compose -f ./"${product}"/build.test.yml down
  done
else
  TAG=edge docker-compose -f ./"${product}"/build.test.yml up --exit-code-from sut
  TAG=edge docker-compose -f ./"${product}"/build.test.yml down
  #if it relates to a sprint, tag it as latest overall
fi