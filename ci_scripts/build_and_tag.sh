#!/usr/bin/env sh
set -x
defaultOS=alpine
product=${1}
os=${2:-${defaultOS}}

test -z "${product}" && exit 199

#uncomment for local
#sprint=$(git tag --points-at HEAD | sed 's/sprint-//')
sprint=$(git tag --points-at "$CI_COMMIT_SHA" | sed 's/sprint-//')
sprint=${sprint}

echo building "${product}"
image="pingidentity/${product}"
if test  -f "${product}/versions" ; then
    versions=$(grep -v "^#" "${product}"/versions)
    echo "Buildind versions: ${versions}"
    is_latest=true
    for version in ${versions} ; do
        fullTag="${version}-${os}-edge"
        #build the edge version of this product
        docker build -t "${image}:${fullTag}" --build-arg SHIM=${os} --build-arg VERSION="${version}" "${product}"/
        if test ${?} -ne 0 ; then
            echo "*** BUILD BREAK ***"
            echo "error on version: ${version}" 
            echo "error on OS     : ${os}" 
            exit 76
        fi
        #if it relates to a sprint, tag the sprint and as latest for version. 
        if test -n "${sprint}" ; then
            docker tag "${image}:${fullTag}" "${image}:${sprint}-${os}-${version}"
            if ${is_latest} ; then
                docker tag "${image}:${fullTag}" "${image}:${sprint}-${os}-latest"
                docker tag "${image}:${fullTag}" "${image}:${os}-latest"
            fi
            if test "${os}" = "${defaultOS}" ; then
                docker tag "${image}:${fullTag}" "${image}:${sprint}-${version}"
                docker tag "${image}:${fullTag}" "${image}:${version}-latest"
                docker tag "${image}:${fullTag}" "${image}:${version}"
                #if it's latest product version and a sprint, then it's "latest" overall and also just "edge". 
                if ${is_latest} ; then
                    docker tag "${image}:${fullTag}" "${image}:latest"
                    docker tag "${image}:${fullTag}" "${image}:${sprint}"
                fi
            fi
        fi

        if test "${os}" = "${defaultOS}" ; then
            docker tag "${image}:${fullTag}" "${image}:${version}-edge"
        fi
    
        if ${is_latest} ; then
            docker tag "${image}:${fullTag}" "${image}:${os}-edge"
            if test "${os}" = "${defaultOS}" ; then
                docker tag "${image}:${fullTag}" "${image}:edge"
            fi
            is_latest=false
        fi
    done
else
    echo "Version-less build"
    fullTag="${os}-edge"
    docker build -t "${image}:${fullTag}" --build-arg SHIM=${os} "${product}"/
    if test ${?} -ne 0 ; then
            echo "*** BUILD BREAK ***"
            exit 76
    fi

    if test "${os}" = "${defaultOS}" ; then
        docker tag "${image}:${fullTag}" "${image}:edge"
    fi
    #tag if sprint, and then also latest
    if test -n "${sprint}" ; then
        docker tag "${image}:${fullTag}" "${image}:${sprint}-${os}"
        if test "${os}" = "${defaultOS}" ; then
            docker tag "${image}:${fullTag}" "${image}:${sprint}"
            docker tag "${image}:${fullTag}" "${image}:latest"
        fi
    fi
fi
