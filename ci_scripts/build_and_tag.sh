#!/usr/bin/env bash
# product=${1}
# defaultShim=${3:-alpine}
# os=${2:-${defaultShim}}
#not implemented version

test -n "${VERBOSE}" && set -x


# make sure have latest pingfoundation
pull_and_tag(){
    ${dryRun} docker pull "${1}"
    ${dryRun} docker tag "${1}" "${2}"
}

pull_and_tag_if_missing ()
{
    _source="${1}"
    shift
    _destination="${1}"
    shift

    if test -n "${_source}" -a -n "${_destination}" -a -z "$(docker image ls -q ${_destination} | sort | uniq )" ; then
        ${dryRun} docker pull "${_source}" || :
        if test -n "$(docker image ls -q ${_source})" ; then
            ${dryRun} docker tag "${_source}" "${_destination}" || :
            while test -n "${1}" ; do
                _tag="${1}"
                shift
                ${dryRun} docker tag "${_destination}" "${_tag}" || :
            done
        fi
    fi
}

tag_and_push(){
    if test "${FOUNDATION_REGISTRY}" = "gcr.io/ping-identity" ; then
        ${dryRun} docker tag "${image}:${1}" "${gcrImage}:${1}-${ciTag}"
        ${dryRun} docker push "${gcrImage}:${1}-${ciTag}"
    fi
}

#
# Usage printing function
#
usage ()
{
cat <<END_USAGE
Usage: ${0} {options}
    where {options} include:

    -p, --product
        The name of the product for which to build a docker image
    -s, --shim
        the name of the operating system for which to build a docker image
    -v, --version
        the version of the product for which to build a docker image
        this setting overrides the versions in the version file of the target product
    --verbose-build
        verbose docker build not using docker buildkit
    --dry-run
        does everything except actually call the docker command and prints it instead
    --help
        Display general usage information
END_USAGE
exit 99
}

DOCKER_BUILDKIT=1
while ! test -z "${1}" ; do
    case "${1}" in
        -d|--default-shim)
            shift
            if test -z "${1}" ; then
                echo "You must provide a default OS Shim"
                usage
            fi
            defaultShim="${1}"
            ;;
        -p|--product)
            shift
            if test -z "${1}" ; then
                echo "You must provide a product to build"
                usage
            fi
            productToBuild="${1}"
            ;;
        -s|--shim)
            shift
            if test -z "${1}" ; then
                echo "You must provide an OS Shim"
                usage
            fi
            shimToBuild="${1}"
            ;;
        -v|--version)
            shift
            if test -z "${1}" ; then
                echo "You must provide a version to build"
                usage
            fi
            versionToBuild="${1}"
            ;;  
        --no-build-kit)
            DOCKER_BUILDKIT=0
            ;;
        --no-cache)
            noCache="--no-cache"
            ;;
        --verbose-build)
            progress="--progress plain"
            ;;
        --dry-run)
            dryRun="echo"
            ;;
        --help)
            usage
            ;;

        *)
            echo "Unrecognized option"
            usage
            ;;
    esac
    shift
done

if test -z "${CI_COMMIT_REF_NAME}" ;then
    CI_PROJECT_DIR="$(cd $(dirname "${0}")/..;pwd)"
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts";
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

if test -z "${productToBuild}" ; then
    echo "You must specify a product."
    usage
fi
if test -f "${productToBuild}/versions.json" ; then
    if test -z "${versionToBuild}" ; then
        echo "You must specify a version."
        usage
    fi
    latestVersion=$( _getLatestVersionFor ${productToBuild} )

    if test -z "${shimToBuild}" ; then
        echo "You must specify a shim."
        usage
    fi
    shimToBuildLongTag=$( _getLongTag "${shimToBuild}" )
    shimToBuildShortTag=$( _getShortTag "${shimToBuild}" )

    if test -z "${defaultShim}" ; then 
        defaultShim=$( _getDefaultShimFor ${productToBuild} ${versionToBuild} )
    fi
fi

image="pingidentity/${productToBuild}"
gcr="gcr.io/ping-identity"
gcrImage="gcr.io/ping-identity/${productToBuild}"

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

if test -z "${isLocalBuild}" ; then
    # we are in CI pipe

    # if foundation was built, we can use that
    # pull_and_tag_if missing is going to check if we have the image with the
    # ${ciTag} tag locally, and if not it will pull it down, tag it with both
    # the ciTag and latest
    pull_and_tag_if_missing "${FOUNDATION_REGISTRY}/pingcommon:${ciTag}" "pingidentity/pingcommon:${ciTag}" "pingidentity/pingcommon:latest"
    pull_and_tag_if_missing "${FOUNDATION_REGISTRY}/pingdatacommon:${ciTag}" "pingidentity/pingdatacommon:${ciTag}" "pingidentity/pingdatacommon:latest"
    pull_and_tag_if_missing "${FOUNDATION_REGISTRY}/pingbase:${shimToBuildLongTag}-${ciTag}" "pingidentity/pingbase:${shimToBuildLongTag}-${ciTag}" "pingidentity/pingbase:${shimToBuildLongTag}"

 
    # if the build has not triggered a foundation build, we use latest
    # note that if the commit triggered the foundation build then the 
    # latest image actually maps to the ciTag image pulled above
    # and no action is taken below
    pull_and_tag_if_missing "${FOUNDATION_REGISTRY}/pingcommon" "pingidentity/pingcommon:latest"
    pull_and_tag_if_missing "${FOUNDATION_REGISTRY}/pingdatacommon" "pingidentity/pingdatacommon:latest"
    pull_and_tag_if_missing "${FOUNDATION_REGISTRY}/pingbase:${shimToBuildLongTag}" "pingidentity/pingbase:${shimToBuildLongTag}"
fi

#Start building product
echo "INFO: Start building ${productToBuild} ${versionToBuild} ${shimToBuild}"

if test -f "${productToBuild}/versions.json" ; then
    # versions=$(grep -v "^#" "${product}"/versions)
    # echo "Building versions: ${versions}"
    # TODO: compute if it is the latest
    # is_latest=true

    # TODO: add JDK version in tag ?
    _jdk=$( _getJDKForProductVersionShim ${productToBuild} ${versionToBuild} ${shimToBuild} )
    test -z "${isLocalBuild}" \
        && pull_and_tag_if_missing \
            "${FOUNDATION_REGISTRY}/pingjvm:${_jdk}_${shimToBuildLongTag}-${ciTag}" \
            "pingidentity/pingjvm:${_jdk}_${shimToBuildLongTag}-${ciTag}" \
            "pingidentity/pingjvm:${_jdk}_${shimToBuildLongTag}"

    fullTag="${versionToBuild}-${shimToBuildLongTag}-edge"
    imageVersion="${productToBuild}-${shimToBuildLongTag}-${versionToBuild}-${currentDate}-${gitRevShort}"
    licenseVersion="$(echo ${versionToBuild}| cut -d. -f1,2)"
    #build the edge version of this product
    DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker build \
        -t "${image}:${fullTag}" \
        ${progress} ${noCache} \
        --build-arg PRODUCT="${productToBuild}" \
        --build-arg JDK="${_jdk}" \
        --build-arg SHIM="${shimToBuild}" \
        --build-arg SHIM_TAG="${shimToBuildLongTag}" \
        --build-arg VERSION="${versionToBuild}" \
        --build-arg IMAGE_VERSION="${imageVersion}" \
        --build-arg IMAGE_GIT_REV="${gitRevLong}" \
        --build-arg LICENSE_VERSION="${licenseVersion}" \
        "${productToBuild}"/
    if test ${?} -ne 0 ; then
        echo "*** BUILD BREAK ***"
        echo "error on version: ${versionToBuild}" 
        echo "error on OS     : ${shimToBuild}"
        docker images 
        exit 76
    fi
    tag_and_push "${fullTag}"

    ${dryRun} docker tag "${image}:${fullTag}" "${image}:${versionToBuild}-${shimToBuildShortTag}-edge" 
    #if it relates to a sprint, tag the sprint and as latest for version. 
    if test -n "${sprint}" ; then
        ${dryRun} docker tag "${image}:${fullTag}" "${image}:${sprint}-${shimToBuildLongTag}-${versionToBuild}"
        tag_and_push "${sprint}-${shimToBuildLongTag}-${versionToBuild}"
        if test "${versionToBuild}" = "${latestVersion}" ; then
            ${dryRun} docker tag "${image}:${fullTag}" "${image}:${sprint}-${shimToBuildLongTag}-latest"
            tag_and_push "${sprint}-${shimToBuildLongTag}-latest"

            ${dryRun} docker tag "${image}:${fullTag}" "${image}:${shimToBuildLongTag}-latest"
            tag_and_push "${shimToBuildLongTag}-latest"
        fi
        if test "${shimToBuild}" = "${defaultShim}" ; then
            ${dryRun} docker tag "${image}:${fullTag}" "${image}:${sprint}-${versionToBuild}"
            tag_and_push "${sprint}-${versionToBuild}"

            ${dryRun} docker tag "${image}:${fullTag}" "${image}:${versionToBuild}-latest"
            tag_and_push "${versionToBuild}-latest"

            ${dryRun} docker tag "${image}:${fullTag}" "${image}:${versionToBuild}"
            tag_and_push "${versionToBuild}"

            #if it's latest product version and a sprint, then it's "latest" overall and also just "edge". 
            if test "${versionToBuild}" = "${latestVersion}" ; then
                ${dryRun} docker tag "${image}:${fullTag}" "${image}:latest"
                tag_and_push "latest"

                ${dryRun} docker tag "${image}:${fullTag}" "${image}:${sprint}"
                tag_and_push "${sprint}"
            fi
        fi
    fi

    if test "${shimToBuild}" = "${defaultShim}" ; then
        ${dryRun} docker tag "${image}:${fullTag}" "${image}:${versionToBuild}-edge"
        tag_and_push "${versionToBuild}-edge"
    fi

    if test "${versionToBuild}" = "${latestVersion}" ; then
        ${dryRun} docker tag "${image}:${fullTag}" "${image}:${shimToBuildLongTag}-edge"
        tag_and_push "${shimToBuildLongTag}-edge"
        if test "${shimToBuild}" = "${defaultShim}" ; then
            ${dryRun} docker tag "${image}:${fullTag}" "${image}:edge"
            tag_and_push edge
        fi
        # is_latest=false
    fi
else
    banner "Version-less build"
    fullTag="${shimToBuildLongTag:+${shimToBuildLongTag}-}edge"
    imageVersion="${productToBuild}-${shimToBuildLongTag:+${shimToBuildLongTag}-}0-${currentDate}-${gitRevShort}"
    # DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker build \
    #     -t "${image}:${fullTag}" \
    #     ${progress} ${noCache} \
    #     ${shimToBuild:+--build-arg SHIM="${shimToBuild}"} \
    #     --build-arg IMAGE_VERSION="${imageVersion}" \
    #     --build-arg IMAGE_GIT_REV="${gitRevLong}" \
    #     "${productToBuild}"/
    DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker build \
        -t "${image}:${fullTag}" \
        ${progress} ${noCache} \
        ${shimToBuild:+--build-arg SHIM="${shimToBuild}"} \
        --build-arg IMAGE_VERSION="${imageVersion}" \
        --build-arg IMAGE_GIT_REV="${gitRevLong}" \
        "${productToBuild}"/
    if test ${?} -ne 0 ; then
            echo "*** BUILD BREAK ***"
            docker images
            exit 76
    fi
    tag_and_push "${fullTag}"
    if test -n "${shimToBuild}" && test "${shimToBuild}" = "${defaultShim}" ; then
        ${dryRun} docker tag "${image}:${fullTag}" "${image}:edge"
        tag_and_push edge
    fi
    #tag if sprint, and then also latest
    if test -n "${sprint}" ; then
        ${dryRun} docker tag "${image}:${fullTag}" "${image}:${sprint}-${shimToBuildLongTag}"
        tag_and_push "${sprint}-${shimToBuildLongTag}"
        if test "${shimToBuild}" = "${defaultShim}" ; then
            ${dryRun} docker tag "${image}:${fullTag}" "${image}:${sprint}"
            tag_and_push "${sprint}"

            ${dryRun} docker tag "${image}:${fullTag}" "${image}:latest"
            tag_and_push "latest"
        fi
    fi
fi
