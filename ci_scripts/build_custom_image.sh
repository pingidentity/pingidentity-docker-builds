#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# This script builds the product images
#
test "${VERBOSE}" = "true" && set -x

#
# Usage printing function
#
usage() {
    test -n "${*}" && echo "${*}"
    cat << END_USAGE
Usage: ${0} {options}
    where {options} include:
    -p, --product
        Required. The name of the product for which to build a custom docker image
        Ex: pingfederate
    -o, --os-shim
        Required. The docker image tagged name of the operating system for which to build a custom docker image.
        Ex: alpine:3.21.0
    -j, --jvm
        Required. The id of the jvm to build
        Ex: al11
    -v, --version
        Required. The version of the product for which to build a custom docker image
        this setting overrides the versions in the version file of the target product
        Ex. 12.0.1
    -s, --sprint
        The Ping release git tag to build the image from. If no sprint git tag is provided,
        the image build will be based on this repository's master branch.
        Ex: 2404
    -z, --zip-url
        The download URL of the product zip file to use for the custom docker image build.
        This parameter can also be specified by the environment variable CUSTOM_PRODUCT_ZIP_URL.
        CUSTOM_PRODUCT_ZIP_URL overwrites this parameter if both are provided.

        If the zip download URL is not provided, the zip file will attempt to download from
        Ping's internal Artificatory for the specified product/version above.
    --help
        Display general usage information
END_USAGE
    exit 99
}

# DOCKER_BUILDKIT is a built-in environment variable for docker and is used. Disable shellcheck.
# shellcheck disable=SC2034
DOCKER_BUILDKIT=1
while ! test -z "${1}"; do
    case "${1}" in
        -p | --product)
            test -z "${2}" && usage "ERROR: You must provide a product name with the specified option ${1}"
            shift
            product_name="${1}"
            ;;
        -o | --os-shim)
            test -z "${2}" && usage "ERROR: You must provide an OS image tagged name with the specified option ${1}"
            shift
            os_image_tagged_name="${1}"
            ;;
        -j | --jvm)
            test -z "${2}" && usage "ERROR: You must provide a JVM ID with the specified option ${1}"
            shift
            jvm_id="${1}"
            ;;
        -v | --version)
            test -z "${2}" && usage "ERROR: You must provide a version with the specified option ${1}"
            shift
            product_version="${1}"
            ;;
        -s | --sprint)
            test -z "${2}" && usage "ERROR: You must provide a sprint git tag with the specified option ${1}"
            shift
            sprint_git_tag="${1}"
            ;;
        -z | --zip-url)
            test -z "${2}" && usage "ERROR: You must provide a zip download URL with the specified option ${1}"
            shift
            zip_download_url="${1}"
            ;;
        --help)
            usage
            ;;
        *)
            usage "Unrecognized option"
            ;;
    esac
    shift
done

# Make sure all 4 required parameters are specified
if test -z "${product_name}" || test -z "${os_image_tagged_name}" || test -z "${jvm_id}" || test -z "${product_version}"; then
    usage "ERROR: You must specify all of the following parameters: Product name, OS shim, JVM ID, and Product version"
fi

if test -z "${CI_COMMIT_REF_NAME}"; then
    CI_PROJECT_DIR="$(
        cd "$(dirname "${0}")/.." || exit 97
        pwd
    )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

# Handle pipeline environment variable that specifies zip download URL.
if test -n "${CUSTOM_PRODUCT_ZIP_URL}"; then
    zip_download_url="${CUSTOM_PRODUCT_ZIP_URL}"
fi

# git checkout the specified git tag for building the image with a specified sprint's hook scripts
# If no sprint version is specified, build will be on master branch
if test -n "${sprint_git_tag}"; then
    # This places the local repository in a detached HEAD state.
    git checkout tags/"${sprint_git_tag}"
    test "${?}" != "0" && echo "ERROR: Failed to checkout tag reference ${sprint_git_tag}" && exit 1
fi

# If a zip download URL is specified, download the zip file and place the product.zip in the tmp folder of the specified
# product name
if test -n "${zip_download_url}"; then
    echo "Retrieving product bits zip file for ${product_name} from ${zip_download_url}"
    curl --request GET --output "${CI_PROJECT_DIR}/${product_name}/tmp/product.zip" "${zip_download_url}"
    test $? -ne 0 && echo "Error: Could not retrieve zip file from ${zip_download_url}" && exit 1
    echo "Successfully retrieved zip file from ${zip_download_url}."
fi

# From here, simply allow ci_scripts/serial_build.sh to handle the build with the provided build configuration.
"${CI_SCRIPTS_DIR}"/serial_build.sh --product "${product_name}" --version "${product_version}" --shim "${os_image_tagged_name}" --jvm "${jvm_id}"
test "${?}" != "0" && echo "ERROR: Failed to run serial_build.sh and build the custom image" && exit 1

# Get this built docker image ID, tag the image and publish to Artifactory
docker_image_id="$(docker images | awk 'NR==2' | awk '{print $3}')"
target_image_name="${ARTIFACTORY_REGISTRY}/${product_name}:${sprint_git_tag}-${product_version}-$(_getLongTag "${os_image_tagged_name}")-${jvm_id}-${ARCH}"
docker tag "${docker_image_id}" "${target_image_name}"
test "${?}" != "0" && echo "ERROR: Failed to docker tag custom image" && exit 1
docker push "${target_image_name}"
test "${?}" != "0" && echo "ERROR: Failed to docker push custom image" && exit 1

exit 0
