#!/usr/bin/env sh
set -x

product=${1}
#uncomment for local
#sprint=$(git tag --points-at HEAD | sed 's/sprint-//')
sprint=$(git tag --points-at "$CI_COMMIT_SHA" | sed 's/sprint-//')
sprint=${sprint}

echo building "${product}"
for os in alpine ubuntu centos ; do
    if test  -f "${product}"/versions; then
        is_latest=true
        versions=$(grep -v "^#" "${product}"/versions)
        for version in ${versions}; do
            fullTag="${version}-${os}-edge"
            image="pingidentity/${product}"
            #build the edge version of this product
            docker build -t "${image}:${fullTag}" --build-arg SHIM=${os} --build-arg VERSION="${version}" "${product}"/
            if test ${?} -ne 0 ; then
                echo "*** BUILD BREAK ***"
                echo "error on version: ${version}" 
                echo "error on OS     : ${os}" 
                exit 76
            fi
            #if it relates to a sprint, tag the sprint and as latest for version. 
            if test -n "${sprint}"; then
                docker tag "${image}:${fullTag}" "${image}:${sprint}-${os}-${version}"
                if test "${os}" = "alpine" ; then
                    docker tag "${image}:${fullTag}" "${image}:${sprint}-${version}"
                    docker tag "${image}:${fullTag}" "${image}:${version}-latest"
                    docker tag "${image}:${fullTag}" "${image}:${version}"
                    #if it's latest product version and a sprint, then it's "latest" overall and also just "edge". 
                    if ${is_latest} ; then
                        docker tag "${image}:${fullTag}" "${image}:latest"
                        docker tag "${image}:${fullTag}" "${image}:edge"
                        docker tag "${image}:${fullTag}" "${image}:${sprint}"
                        is_latest=false
                    fi
                fi
            fi
            #if it's latest product version but no sprint, it's still "edge"
            if ${is_latest} ; then
                docker tag "${image}:${version}-edge" "${image}:edge"
                is_latest=false
            fi
        done
    else
        docker build -t "${image}:edge" "${product}"/
        if test ${?} -ne 0 ; then
                echo "*** BUILD BREAK ***"
                exit 76
        fi
        #tag if sprint, and then also latest
        if test -n "${sprint}" && test os = "alpine" ; then
            docker tag "${image}:edge" "${image}:latest"
            docker tag "${image}:edge" "${image}:${sprint}"
        fi
    fi
done