#!/usr/bin/env bash
product=${1}
defaultOS=${3:-alpine}
os=${2:-${defaultOS}}
image="pingidentity/${product}"
gcr="gcr.io/ping-identity"
gcrImage="gcr.io/ping-identity/${product}"
#not implemented version

# make sure have latest pingfoundation
pull_and_tag(){
    docker pull "${1}"
    docker tag "${1}" "${2}"
}

pull_and_tag_if_missing ()
{
    test -z "$(docker image ls -q ${2})" && pull_and_tag ${*} || :
}

tag_and_push(){
    if test "${FOUNDATION_REGISTRY}" = "gcr.io/ping-identity" ; then
        docker tag "${image}:${1}" "${gcrImage}:${1}-${ciTag}"
        docker push "${gcrImage}:${1}-${ciTag}"
    fi
}

HERE=$(cd $(dirname "${0}");pwd)
if test -n "${CI_COMMIT_REF_NAME}" ;then
    . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
    # shellcheck source=./ci_tools.lib.sh
    . "${HERE}/ci_tools.lib.sh"
fi

set -e
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

# Get the components for the IMAGE_VERSION and IMAGE_GIT_REV variables
currentDate=$( date +"%y%m%d" )
# UNCOMMENT THIS FOR LOCAL TESTING
# CI_COMMIT_REF_NAME="build-improve-ci"
# CI_COMMIT_SHORT_SHA="6a153eb9"


for tag in $( git tag --points-at "$gitRevLong" ) ; do
    if test -z "$( echo ${tag} | sed 's/^[0-9]\{4\}$//' )" ; then
        sprint="${tag}"
        break
    fi
done
# sprint=${sprint}

if test -z "${CI_COMMIT_REF_NAME}" ; then
    # We are building locally (not in CI)
    pull_and_tag_if_missing "${gcr}/pingcommon" "pingidentity/pingcommon"
    pull_and_tag_if_missing "${gcr}/pingdatacommon" "pingidentity/pingdatacommon"
    pull_and_tag_if_missing "${gcr}/pingbase:${os}" "pingidentity/pingbase:${os}"
else
    if test "$( docker pull ${FOUNDATION_REGISTRY}/pingcommon:${ciTag} )" ; then
        # we are in CI pipe and pingfoundation was built in previous job. 
        pull_and_tag "${FOUNDATION_REGISTRY}/pingcommon:${ciTag}" "pingidentity/pingcommon"
        pull_and_tag "${FOUNDATION_REGISTRY}/pingdatacommon:${ciTag}" "pingidentity/pingdatacommon"
        pull_and_tag "${FOUNDATION_REGISTRY}/pingbase:${os}-${ciTag}" "pingidentity/pingbase:${os}"
    else
        # we are in CI pipe and need to just use "latest"
        docker pull "${FOUNDATION_REGISTRY}/pingcommon"
        docker pull "${FOUNDATION_REGISTRY}/pingdatacommon"
        docker pull "${FOUNDATION_REGISTRY}/pingbase:${os}"
    fi
fi

#Start building product
echo "INFO: Start building ${product}"

if test  -f "${product}/versions" ; then
    versions=$(grep -v "^#" "${product}"/versions)
    echo "Building versions: ${versions}"
    is_latest=true
    for version in ${versions} ; do
        fullTag="${version}-${os}-edge"
        imageVersion="${product}-${os}-${version}-${currentDate}-${gitRevShort}"
        licenseVersion="$(echo ${version}| cut -d. -f1,2)"
        #build the edge version of this product
        DOCKER_BUILDKIT=1 docker build \
            -t "${image}:${fullTag}" \
            --build-arg SHIM="${os}" \
            --build-arg VERSION="${version}" \
            --build-arg IMAGE_VERSION="${imageVersion}" \
            --build-arg IMAGE_GIT_REV="${gitRevLong}" \
            --build-arg LICENSE_VERSION="${licenseVersion}" \
            "${product}"/
        if test ${?} -ne 0 ; then
            echo "*** BUILD BREAK ***"
            echo "error on version: ${version}" 
            echo "error on OS     : ${os}" 
            exit 76
        fi
        tag_and_push "${fullTag}"
        #if it relates to a sprint, tag the sprint and as latest for version. 
        if test -n "${sprint}" ; then
            docker tag "${image}:${fullTag}" "${image}:${sprint}-${os}-${version}"
            tag_and_push "${sprint}-${os}-${version}"
            if ${is_latest} ; then
                docker tag "${image}:${fullTag}" "${image}:${sprint}-${os}-latest"
                tag_and_push "${sprint}-${os}-latest"

                docker tag "${image}:${fullTag}" "${image}:${os}-latest"
                tag_and_push "${os}-latest"
            fi
            if test "${os}" = "${defaultOS}" ; then
                docker tag "${image}:${fullTag}" "${image}:${sprint}-${version}"
                tag_and_push "${sprint}-${version}"

                docker tag "${image}:${fullTag}" "${image}:${version}-latest"
                tag_and_push "${version}-latest"

                docker tag "${image}:${fullTag}" "${image}:${version}"
                tag_and_push "${version}"
                #if it's latest product version and a sprint, then it's "latest" overall and also just "edge". 
                if ${is_latest} ; then
                    docker tag "${image}:${fullTag}" "${image}:latest"
                    tag_and_push "latest"

                    docker tag "${image}:${fullTag}" "${image}:${sprint}"
                    tag_and_push "${sprint}"
                fi
            fi
        fi

        if test "${os}" = "${defaultOS}" ; then
            docker tag "${image}:${fullTag}" "${image}:${version}-edge"
            tag_and_push "${version}-edge"
        fi
    
        if ${is_latest} ; then
            docker tag "${image}:${fullTag}" "${image}:${os}-edge"
            tag_and_push "${os}-edge"
            if test "${os}" = "${defaultOS}" ; then
                docker tag "${image}:${fullTag}" "${image}:edge"
                tag_and_push edge
            fi
            is_latest=false
        fi
    done
else
    echo "Version-less build"
    fullTag="${os}-edge"
    imageVersion="${product}-${os}-0-${currentDate}-${gitRevShort}"
    DOCKER_BUILDKIT=1 docker build \
        -t "${image}:${fullTag}" \
        --build-arg SHIM="${os}" \
        --build-arg IMAGE_VERSION="${imageVersion}" \
        --build-arg IMAGE_GIT_REV="${gitRevLong}" \
        "${product}"/
    if test ${?} -ne 0 ; then
            echo "*** BUILD BREAK ***"
            exit 76
    fi
    tag_and_push "${fullTag}"
    if test "${os}" = "${defaultOS}" ; then
        docker tag "${image}:${fullTag}" "${image}:edge"
        tag_and_push edge
    fi
    #tag if sprint, and then also latest
    if test -n "${sprint}" ; then
        docker tag "${image}:${fullTag}" "${image}:${sprint}-${os}"
        tag_and_push "${sprint}-${os}"
        if test "${os}" = "${defaultOS}" ; then
            docker tag "${image}:${fullTag}" "${image}:${sprint}"
            tag_and_push "${sprint}"

            docker tag "${image}:${fullTag}" "${image}:latest"
            tag_and_push "latest"
        fi
    fi
fi

if test -n "${CI_COMMIT_REF_NAME}" ; then
    history | tail -100
fi