#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# This script archives all Ping Identity Docker Images from
# https://hub.docker.com/u/pingidentity to Artifactory
#
test "${VERBOSE}" = "true" && set -x

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
docker_config_hub_dir="/root/.docker-hub"
docker_config_default_dir="/root/.docker"
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

# Revoke any trust data from notary for a specific images archive to artifactory
overwrite_and_archive_image() {
    test -z "${1}" && echo_red "ERROR: The function overwrite_and_archive_image requires a repository name." && exit 1
    test -z "${2}" && echo_red "ERROR: The function overwrite_and_archive_image requires an image tag." && exit 1
    test -z "${3}" && echo_red "ERROR: The function overwrite_and_archive_image requires an architecture." && exit 1

    target_image="${ARTIFACTORY_REGISTRY}/${1}:${2}-${3}"

    # Revoke trust data for the tag
    export DOCKER_CONTENT_TRUST_SERVER="https://notaryserver:4443"
    exec_cmd_or_fail docker --config "${docker_config_default_dir}" trust revoke --yes "${target_image}"
    unset DOCKER_CONTENT_TRUST_SERVER

    # Archive the image
    archive_image "${1}" "${2}" "${3}"
}

# Authenticate to DockerHub and output the login data to $api_output_file
authenticate_to_dockerhub() {
    banner "Authenticating to DockerHub"
    http_response_code=$(curl --silent --request "POST" --write-out '%{http_code}' --output "${api_output_file}" --header "Content-Type: application/json" --data '{"username": "'"${DOCKER_USERNAME}"'", "password": "'"${DOCKER_ACCESS_TOKEN}"'"}' "https://hub.docker.com/v2/users/login/")
    if test "${http_response_code}" -eq 200; then
        echo "Successfully Retrieved Login Auth Token from DockerHub"
    else
        echo_red "${http_response_code}: Unable to login to dockerhub for tag deletion" && exit 1
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
    test "${http_result_code}" -ne 200 &&
        echo "ERROR: ${http_result_code} Unable to retrieve the list of tags from ${dockerhub_api_domain}/v2/namespaces/${api_namespace}/repositories/${repository}/tags?page=${1}&page_size=${2}" &&
        echo "Response body:" &&
        cat "${api_output_file}" &&
        exit 1
}

get_artifactory_repository_tags_data() {
    test -z "${1}" && echo_red "ERROR: The function get_artifactory_repository_tags_data requires a repository name." && exit 1

    http_result_code=$(api_curl \
        --header "Authorization: Bearer ${art_auth_token}" \
        --output "${api_output_file}" \
        --request "GET" \
        "${artifactory_api_domain}/api/docker/docker-builds/v2/${1}/tags/list")
    test "${http_result_code}" -ne 200 &&
        echo "ERROR: ${http_result_code} Unable to retrieve the list of tags from ${artifactory_api_domain}/api/docker/docker-builds/v2/${repository}/tags/list" &&
        echo "Response body:" &&
        cat "${api_output_file}" &&
        exit 1
}

get_artifactory_repository_signed_tags_data() {
    test -z "${1}" && echo_red "ERROR: The function get_artifactory_repository_signed_tags_data requires a repository name." && exit 1

    target_repository="${ARTIFACTORY_REGISTRY}/${1}"

    export DOCKER_CONTENT_TRUST_SERVER="https://notaryserver:4443"
    docker --config "${docker_config_default_dir}" trust inspect "${target_repository}" > "${api_output_file}"

    test "${?}" -ne 0 &&
        echo "ERROR: ${http_result_code} Unable to retrieve repository trust data for ${target_repository}" &&
        echo "Response body:" &&
        cat "${api_output_file}" &&
        exit 1

    unset DOCKER_CONTENT_TRUST_SERVER
}

get_dockerhub_specific_tag_data() {
    test -z "${1}" && echo_red "ERROR: The function get_dockerhub_specific_tag_data requires a repository name." && exit 1
    test -z "${2}" && echo_red "ERROR: The function get_dockerhub_specific_tag_data requires an image tag." && exit 1

    http_result_code=$(api_curl \
        --header "Authorization: Bearer ${dockerhub_auth_token}" \
        --output "${api_output_file}" \
        --request "GET" \
        "${dockerhub_api_domain}/v2/namespaces/${api_namespace}/repositories/${repository}/tags/${tag}")
    test "${http_result_code}" -ne 200 &&
        echo "ERROR: ${http_result_code} Unable to retrieve tag information from ${dockerhub_api_domain}/v2/namespaces/${api_namespace}/repositories/${repository}/tags/${tag}" &&
        echo "Response body:" &&
        cat "${api_output_file}" &&
        exit 1
}

######################
# Main Archive Section
######################

# Authenticate to DockerHub by retrieving the Auth Token
authenticate_to_dockerhub
dockerhub_auth_token=$(jq -r .token "${api_output_file}")

# Define list of all DockerHub repositories for the PingDevops Integrations Team
repository_list="ldap-sdk-tools pingaccess pingauthorize pingauthorizepap pingcentral pingdataconsole pingdatasync pingdelegator pingdirectory pingdirectoryproxy pingfederate pingintelligence pingtoolkit"

# Loop through DockerHub/Artifactory repositories
for repository in ${repository_list}; do
    banner "Archiving for repository: ${repository}"
    page_size=100
    page_number=1

    # Retrieve all unique non-edge image tags from DockerHub
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

        # Get the list of all non-edge images in each DockerHub repository
        dockerhub_repository_tag_list="${dockerhub_repository_tag_list}${dockerhub_repository_tag_list:+ }$(jq -r '[.results[] | select(.name | match("^(?!.*edge)")) | .name] | unique | .[]' "${api_output_file}")"
    done # Done looping pages of tags data

    # Retrieve all image tags from Artifactory
    get_artifactory_repository_tags_data "${repository}"
    artifactory_repository_tag_list=$(jq '.tags[]' "${api_output_file}")

    # Retrieve all signed image tags from Artifactory
    get_artifactory_repository_signed_tags_data "${repository}"
    artifactory_repository_signed_tag_list=$(jq '[.[] | .SignedTags[] | .SignedTag] | unique | .[]' "${api_output_file}")

    # Loop through each tag from the DockerHub Repository
    for tag in ${dockerhub_repository_tag_list}; do
        # Loop through arch specific tags
        get_dockerhub_specific_tag_data "${repository}" "${tag}"
        arch_list_for_tag=$(jq -r '.images[] | .architecture' "${api_output_file}")

        for arch in ${arch_list_for_tag}; do
            arch_tag="${tag}-${arch}"

            # Check to see if the DockerHub tag is already archived on Artifactory
            if test "${artifactory_repository_tag_list#*"\"${arch_tag}\""}" != "${artifactory_repository_tag_list}"; then
                # The current tag is already archived.
                # Either the tag is a sprint tag, or a sliding latest tag.
                # If it is a sprint tag, skip archive process.
                # If it is a latest tag, re-archive the image if it has been updated in the past 60 days

                # Check to see if tag is a sprint tag
                if test "${arch_tag#*[0-9][0-9][0-9][0-9]}" != "${arch_tag}"; then
                    echo "INFO: Sprint tag ${arch_tag} is already archived. Skipping..."
                else
                    # Note, these date command flags are specific to the busybox date command
                    iso_date_last_updated=$(jq -r '.last_updated' "${api_output_file}" | sed -e 's/T.*//g')
                    last_updated_time=$(($(date -d "${iso_date_last_updated}" +%s)))
                    sixty_days_ago=$(($(date +%s) - (60 * 24 * 60 * 60)))
                    if test ${last_updated_time} -gt ${sixty_days_ago}; then
                        # The latest tag has been updated in the past 60 days. Overwrite the archive.
                        echo "INFO: Archiving latest updated tag ${arch_tag} to Artifactory"

                        # Check to see if the Artifactory tag is signed. If not, archive directly, instead of overwriting trust data.
                        if test "${artifactory_repository_signed_tag_list#*"\"${arch_tag}\""}" != "${artifactory_repository_signed_tag_list}"; then
                            # The current tag is signed. Overwrite trust data.
                            overwrite_and_archive_image "${repository}" "${tag}" "${arch}"
                        else
                            # The current tag is not signed. Archive image directly.
                            echo "WARN: Image tag ${arch_tag} has no trust data. Skipping trust data deletion..."
                            archive_image "${repository}" "${tag}" "${arch}"
                        fi
                    else
                        echo "INFO: Latest tag ${arch_tag} is already archived and not updated. Skipping..."
                    fi
                fi
            else
                # The tag is not archived on Artifactory. Do so.
                echo "INFO: Archiving new tag ${arch_tag} to Artifactory"
                archive_image "${repository}" "${tag}" "${arch}"
            fi
        done # looping through architectures
    done     # looping through tags

    # Be sure to only use the tags from each individual repository
    unset artifactory_repository_tag_list
    unset dockerhub_repository_tag_list
done # looping through dockerhub repositories

exit 0
