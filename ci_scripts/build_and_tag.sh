#!/usr/bin/env sh
set -x
defaultOS=alpine
product=${1}
os=${2:-${defaultOS}}

test -z "${product}" && exit 199

#uncomment for local
#sprint=$(git tag --points-at HEAD | sed 's/sprint-//')
# sprint=$(git tag --points-at "$CI_COMMIT_SHA" | sed 's/sprint-//')

#
# The previous mechanism did not factor into account the possibility
# that multiple tags may point to the same commit SHA
#
# Also, we have changed the release tag naming convention to be
# just 4 digits YYMM
# To test for this, we remove 4 digits from the and 
# check that the result is empty
#
# This is still not perfect because we will select the first
# tag that happens to be 4 consecutive digits so we will have to
# make sure we never point 2 4-digit tags to the same commit
#
for tag in $(git tag --points-at "$CI_COMMIT_SHA") ; do
    if test -z "$(echo ${tag} | sed 's/^[0-9]\{4\}$//')" ; then
        sprint=${tag}
        break
    fi
done
# sprint=${sprint}

# Get the components for the IMAGE_VERSION and IMAGE_GIT_REV variables
currentDate=$( date +"%y%m%d" )
gitRevShort=$( git rev-parse --short=4 "$CI_COMMIT_SHA" )
gitRevLong=$( git rev-parse "$CI_COMMIT_SHA" )

echo building "${product}"
image="pingidentity/${product}"
if test  -f "${product}/versions" ; then
    versions=$(grep -v "^#" "${product}"/versions)
    echo "Buildind versions: ${versions}"
    is_latest=true
    for version in ${versions} ; do
        fullTag="${version}-${os}-edge"
        imageVersion="${product}-${os}-${version}-${currentDate}-${gitRevShort}"
        #build the edge version of this product
        docker build -t "${image}:${fullTag}" --build-arg SHIM="${os}" --build-arg VERSION="${version}" --build-arg IMAGE_VERSION="${imageVersion}" --build-arg IMAGE_GIT_REV="${gitRevLong}" "${product}"/
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
    imageVersion="${product}-${os}-0-${currentDate}-${gitRevShort}"
    docker build -t "${image}:${fullTag}" --build-arg SHIM="${os}" --build-arg IMAGE_VERSION="${imageVersion}" --build-arg IMAGE_GIT_REV="${gitRevLong}" "${product}"/
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
