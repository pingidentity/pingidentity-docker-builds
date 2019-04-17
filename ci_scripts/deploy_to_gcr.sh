#!/usr/bin/env sh
set -x

product="$1"
tags=$(docker images "pingidentity/${product}*" --format "{{.Tag}}" -q)
for tag in $tags ; do
  docker tag pingidentity/"$product":"$tag" gcr.io/ping-devops-gte/"$product":"$tag"
  docker push gcr.io/ping-devops-gte/"$product":"$tag"
done