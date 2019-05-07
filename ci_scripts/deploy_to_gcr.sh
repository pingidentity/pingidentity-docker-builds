#!/usr/bin/env sh
set -x

product="$1"
tags=$(docker images "pingidentity/${product}*" --format "{{.Tag}}" -q)
for tag in $tags ; do
  docker tag pingidentity/"$product":"$tag" gcr.io/ping-identity/"$product":"$tag"
  docker push gcr.io/ping-identity/"$product":"$tag"
done