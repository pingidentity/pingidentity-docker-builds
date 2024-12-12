#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# This script archives all Ping Identity Docker Images from
# https://hub.docker.com/u/pingidentity to Artifactory
#
test "${VERBOSE}" = "true" && set -x

# Usage printing function
usage() {
    test -n "${*}" && echo "${*}"
    cat << END_USAGE
Usage: ${0} {options}
    where {options} include:
    -p, --product
        Specifies the DockerHub Ping product from which images
        will be archived into the internal Artifactory repositories.

        The following are valid products to archive:
        ldap-sdk-tools pingaccess pingauthorize pingauthorizepap
        pingcentral pingdataconsole pingdatasync pingdelegator pingdirectory
        pingdirectoryproxy pingfederate pingintelligence pingtoolkit
    --help
        Display general usage information
END_USAGE
    exit 99
}

while ! test -z "${1}"; do
    case "${1}" in
        -p | --product)
            shift
            repository="${1}"
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

# source ci_tools.lib.sh
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

# Define script variables
dockerhub_api_domain="https://hub.docker.com"
artifactory_api_domain="${ARTIFACTORY_SHORT_URL}"
api_namespace="pingidentity"
api_output_file=$(mktemp)
docker_config_hub_dir="$HOME/.docker-hub"
docker_config_default_dir="$HOME/.docker"
art_auth_token="${ARTIFACTORY_AUTH_TOKEN}"

# Make a reliable curl call
api_curl() {
    # Retry numbers come from (5 + 5) * 6 = 60
    curl \
        --connect-timeout 5 \
        --location \
        --retry 6 \
        --retry-connrefused \
        --retry-delay 5 \
        --retry-max-time 60 \
        --silent \
        --show-error \
        --write-out '%{http_code}' \
        "${@}"
}

# Archive a specific dockerhub image to artifactory
archive_image() {
    test -z "${1}" && echo_red "ERROR: The function archive_image requires a repository name." && exit 1
    test -z "${2}" && echo_red "ERROR: The function archive_image requires an image tag." && exit 1
    test -z "${3}" && echo_red "ERROR: The function archive_image requires an architecture." && exit 1

    # Loop through all the image digests, pull them down, tag them, and publish them
    digest=$(jq -r --arg cur_arch "${3}" '.images[] | select(.architecture == $cur_arch) | .digest' "${api_output_file}")

    # initialize source and target information
    source_image="${api_namespace}/${1}@${digest}"
    target_image="${ARTIFACTORY_REGISTRY}/${1}:${2}-${3}"

    # Pull down the image
    exec_cmd_or_retry docker --config "${docker_config_hub_dir}" pull "${source_image}"

    # Tag the pulled image for Artifactory
    exec_cmd_or_fail docker tag "${source_image}" "${target_image}"

    # Push and sign the images to the Artifactory archive
    export DOCKER_CONTENT_TRUST_SERVER="https://notaryserver:4443"
    exec_cmd_or_retry docker --config "${docker_config_default_dir}" trust sign "${target_image}"
    unset DOCKER_CONTENT_TRUST_SERVER

    # Clean up image locally after it has been archived.
    exec_cmd_or_fail docker image rm -f "${target_image}"
    exec_cmd_or_fail docker image rm -f "${source_image}"

    echo "INFO: Successfully archived image: ${target_image}"
}

# Authenticate to DockerHub and output the login data to $api_output_file
authenticate_to_dockerhub() {
    banner "Authenticating to DockerHub"
    http_response_code=$(curl --silent --request "POST" --write-out '%{http_code}' --output "${api_output_file}" --header "Content-Type: application/json" --data '{"username": "'"${DOCKER_USERNAME}"'", "password": "'"${DOCKER_ACCESS_TOKEN}"'"}' "https://hub.docker.com/v2/users/login/")
    if test "${http_response_code}" -eq 200; then
        echo "Successfully Retrieved Login Auth Token from DockerHub"
    else
        echo_red "${http_response_code}: Unable to authenticate with DockerHub" && exit 1
    fi
}

# Retrieve DockerHub tags data for a specific repository, and output the data to $api_output_file
get_dockerhub_repository_tags_data() {
    test -z "${1}" && echo_red "ERROR: The function get_dockerhub_repository_tags_data requires a repository name." && exit 1
    test -z "${2}" && echo_red "ERROR: The function get_dockerhub_repository_tags_data requires a page number." && exit 1
    test -z "${3}" && echo_red "ERROR: The function get_dockerhub_repository_tags_data requires a page size." && exit 1

    http_result_code=$(api_curl \
        --header "Authorization: Bearer ${dockerhub_auth_token}" \
        --output "${api_output_file}" \
        --request "GET" \
        "${dockerhub_api_domain}/v2/namespaces/${api_namespace}/repositories/${1}/tags?page=${2}&page_size=${3}")
    if test "${http_result_code}" != "200"; then
        # Re-Authenticate to DockerHub by retrieving the Auth Token
        # The avoids the auth token timeout of 60m
        authenticate_to_dockerhub
        dockerhub_auth_token=$(jq -r .token "${api_output_file}")

        # Try the curl tag retrieval again
        http_result_code=$(api_curl \
            --header "Authorization: Bearer ${dockerhub_auth_token}" \
            --output "${api_output_file}" \
            --request "GET" \
            "${dockerhub_api_domain}/v2/namespaces/${api_namespace}/repositories/${1}/tags?page=${2}&page_size=${3}")

        if test "${http_result_code}" != "200"; then
            echo "ERROR: ${http_result_code} Unable to retrieve the list of tags from ${dockerhub_api_domain}/v2/namespaces/${api_namespace}/repositories/${repository}/tags?page=${1}&page_size=${2}"
            echo "Response body:"
            cat "${api_output_file}"
            exit 1
        fi
    fi
}

get_artifactory_repository_tags_data() {
    test -z "${1}" && echo_red "ERROR: The function get_artifactory_repository_tags_data requires a repository name." && exit 1

    http_result_code=$(api_curl \
        --header "Authorization: Bearer ${art_auth_token}" \
        --output "${api_output_file}" \
        --request "GET" \
        "${artifactory_api_domain}/api/docker/docker-builds/v2/${1}/tags/list")
    if test "${http_result_code}" != "200"; then
        # Try the curl tag retrieval again
        http_result_code=$(api_curl \
            --header "Authorization: Bearer ${art_auth_token}" \
            --output "${api_output_file}" \
            --request "GET" \
            "${artifactory_api_domain}/api/docker/docker-builds/v2/${1}/tags/list")
        if test "${http_result_code}" != "200"; then
            echo "ERROR: ${http_result_code} Unable to retrieve the list of tags from ${artifactory_api_domain}/api/docker/docker-builds/v2/${repository}/tags/list"
            echo "Response body:"
            cat "${api_output_file}"
            exit 1
        fi
    fi
}

get_dockerhub_specific_tag_data() {
    test -z "${1}" && echo_red "ERROR: The function get_dockerhub_specific_tag_data requires a repository name." && exit 1
    test -z "${2}" && echo_red "ERROR: The function get_dockerhub_specific_tag_data requires an image tag." && exit 1

    http_result_code=$(api_curl \
        --header "Authorization: Bearer ${dockerhub_auth_token}" \
        --output "${api_output_file}" \
        --request "GET" \
        "${dockerhub_api_domain}/v2/namespaces/${api_namespace}/repositories/${repository}/tags/${tag}")
    if test "${http_result_code}" != "200"; then
        # Re-Authenticate to DockerHub by retrieving the Auth Token
        # The avoids the auth token timeout of 60m
        authenticate_to_dockerhub
        dockerhub_auth_token=$(jq -r .token "${api_output_file}")

        # Try the curl again
        http_result_code=$(api_curl \
            --header "Authorization: Bearer ${dockerhub_auth_token}" \
            --output "${api_output_file}" \
            --request "GET" \
            "${dockerhub_api_domain}/v2/namespaces/${api_namespace}/repositories/${repository}/tags/${tag}")

        if test "${http_result_code}" != "200"; then
            echo "ERROR: ${http_result_code} Unable to retrieve tag information from ${dockerhub_api_domain}/v2/namespaces/${api_namespace}/repositories/${repository}/tags/${tag}"
            echo "Response body:"
            cat "${api_output_file}"
            exit 1
        fi
    fi
}

######################
# Main Archive Section
######################

# Authenticate to DockerHub by retrieving the Auth Token
authenticate_to_dockerhub
dockerhub_auth_token=$(jq -r .token "${api_output_file}")

# Define list of all DockerHub repositories for the PingDevops Integrations Team
repository_list="ldap-sdk-tools pingaccess pingauthorize pingauthorizepap pingcentral pingdataconsole pingdatasync pingdelegator pingdirectory pingdirectoryproxy pingfederate pingintelligence pingtoolkit"

# Make sure repository is set by user, or exit
if test -z "${repository}"; then
    usage "A product name supplied by --product flag is required by this script."
fi

# Make sure the user-supplied repository is in the above accepted repository list
if test "${repository_list#*"${repository}"}" = "${repository_list}"; then
    usage "Invalid repository ${repository} supplied. Valid repositories are ${repository_list}"
fi

banner "Archiving for repository: ${repository}"
page_size=100
page_number=1

# Retrieve all unique non-edge non-latest image tags from DockerHub
while test "${page_number}" -gt "0"; do
    get_dockerhub_repository_tags_data "${repository}" "${page_number}" "${page_size}"

    # Check to see if there is more tags on the next page
    next_url=$(jq -r '.next' "${api_output_file}")
    if test "${next_url}" != "null"; then
        page_number=$((page_number + 1))
    else
        # Stop looping while statement
        page_number=0
    fi

    # Get the list of all non-edge and non-latest images in each DockerHub repository
    page_images_list=$(jq -r '[.results[] | select(.name | match("^(?!.*edge)")) | select(.name | match("^(?!.*latest)"))  | .name] | unique | .[]' "${api_output_file}")

    # Concatenate the list to the current list seperated by a space
    dockerhub_repository_tag_list="${dockerhub_repository_tag_list}${dockerhub_repository_tag_list:+ }${page_images_list}"
done # Done looping pages of tags data

# Retrieve all image tags from Artifactory
get_artifactory_repository_tags_data "${repository}"
artifactory_repository_tag_list=$(jq '.tags[]' "${api_output_file}")

# Loop through each tag from the DockerHub Repository
for tag in ${dockerhub_repository_tag_list}; do
    # Artifactory tags are archived in the format "${tag}-${arch}"
    # Here, we only want to see if ANY tag regardless of arch is already archived.
    # If so, we can skip the below API call to dockerhub to retrieve arch information
    # And skip archiving the tag
    # Check to see if the DockerHub tag is already archived on Artifactory
    # This regex replacement with sed is much easier than pattern matching. Disable shellcheck.
    # shellcheck disable=SC2001
    replaced_artifactory_repository_tag_list="$(echo "${artifactory_repository_tag_list}" | sed -e "s/\"${tag}-[[:alnum:]]*\"$/REPLACE/g")"

    if test "${replaced_artifactory_repository_tag_list}" != "${artifactory_repository_tag_list}"; then
        # The tag is archived on Artifactory
        echo "INFO: Tag ${tag} already archived to Artifactory. Skipping..."
    else
        # The tag is not archived on Artifactory for ANY arch. Do so.

        # Loop through arch specific tags
        get_dockerhub_specific_tag_data "${repository}" "${tag}"
        arch_list_for_tag=$(jq -r '.images[] | .architecture' "${api_output_file}")

        for arch in ${arch_list_for_tag}; do
            echo "INFO: Archiving new tag ${tag}-${arch} to Artifactory"
            archive_image "${repository}" "${tag}" "${arch}"

        done # looping through architectures
    fi
done # looping through tags

# Be sure to only use the tags from each individual repository
unset artifactory_repository_tag_list
unset dockerhub_repository_tag_list

exit 0
