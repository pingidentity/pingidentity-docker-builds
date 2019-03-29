#!/usr/bin/env sh
set -x

#define latest product versions
pingfederate_latest_version=9.2.1
pingdirectory_latest_version=7.2.0.1
pingaccess_latest_version=5.2.0
pingdatasync_latest_version=7.2.0.1
pingdataconsole_latest_version=7.2.0.1


product=${1}
if [ -n "$2" ] ; then
  sprint="$2"-
else
  sprint=""
fi

echo building "${product}"
if test  -f "${product}"/versions; then
  is_latest=true
  versions=$(cat "${product}"/versions)
  for version in ${versions}; do      
    #build the edge version of this product
    docker build -t pingidentity/"${product}":"${version}"-edge --build-arg VERSION="${version}" "${product}"/
    #if it relates to a sprint, tag the spring and as latest for version. 
    if test -n "${sprint}"; then
      docker tag pingidentity/"${product}":"${version}"-edge pingidentity/"${product}":"${sprint}""${version}"
      docker tag pingidentity/"${product}":"${sprint}""${version}" pingidentity/"${product}":"${version}"-latest
      #if it's latest product version and a sprint, then it's "latest" overall and also just "edge". 
      if ${is_latest} ; then
        docker tag pingidentity/"${product}":"${version}"-edge pingidentity/"${product}":latest
        docker tag pingidentity/"${product}":"${version}"-edge pingidentity/"${product}":edge
        is_latest=false
      fi
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