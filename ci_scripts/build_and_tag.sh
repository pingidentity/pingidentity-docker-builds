#!/usr/bin/env sh
set -x

product=${1}
#uncomment for local
#sprint=$(git tag --points-at HEAD | sed 's/sprint-//')
sprint=$(git tag --points-at "$CI_COMMIT_BEFORE_SHA" | sed 's/sprint-//')
sprint=${sprint}

echo building "${product}"
if test  -f "${product}"/versions; then
  is_latest=true
  versions=$(grep -v "^#" "${product}"/versions)
  for version in ${versions}; do      
    #build the edge version of this product
    docker build -t pingidentity/"${product}":"${version}"-edge --build-arg VERSION="${version}" "${product}"/
    #if it relates to a sprint, tag the spring and as latest for version. 
    if test -n "${sprint}"; then
      docker tag pingidentity/"${product}":"${version}"-edge pingidentity/"${product}":"${sprint}"-"${version}"
      docker tag pingidentity/"${product}":"${version}"-edge pingidentity/"${product}":"${version}"-latest
      docker tag pingidentity/"${product}":"${version}"-edge pingidentity/"${product}":"${version}"
      #if it's latest product version and a sprint, then it's "latest" overall and also just "edge". 
      if ${is_latest} ; then
        docker tag pingidentity/"${product}":"${version}"-edge pingidentity/"${product}":latest
        docker tag pingidentity/"${product}":"${version}"-edge pingidentity/"${product}":edge
        docker tag pingidentity/"${product}":"${version}"-edge pingidentity/"${product}":"${sprint}"
        is_latest=false
      fi
    fi
    #if it's latest product version but no sprint, it's still "edge"
    if ${is_latest} ; then
      docker tag pingidentity/"${product}":"${version}"-edge pingidentity/"${product}":edge
      is_latest=false
    fi
  done
else
  docker build -t pingidentity/"${product}":edge "${product}"/
  #tag if sprint, and then also latest
  if test -n "${sprint}"; then
    docker tag pingidentity/"${product}":edge pingidentity/"${product}":latest
    docker tag pingidentity/"${product}":edge pingidentity/"${product}":"${sprint}"
  fi
fi