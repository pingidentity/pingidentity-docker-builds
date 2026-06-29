#!/usr/bin/env bash
# Copyright © 2026 Ping Identity Corporation

#
# Ping Identity DevOps - CI scripts
#
# This script creates and pushes multi-arch image manifests to registries based on the
# registries listed in the product's versions.json file
#
test "${VERBOSE}" = "true" && set -x

# Usage printing function
usage() {
    cat << END_USAGE
Usage: ${0} {options}
    where {options} include:

    -p, --product
        The name of the product for which to build a manifest
    --help
        Display general usage information
END_USAGE
    test -n "${*}" && echo "${*}"
    exit 99
}

# Creates and Publishes Multi-Arch Image Manifests
# Signs the Resulting Manifest with Cosign
create_manifest_and_push_and_sign() {
    local target_manifest_name="${1}"
    local ref="${target_registry_url}/${product_to_deploy}:${target_manifest_name}"

    LAST_PUSHED_DIGEST=""
    create_manifest_and_push "${target_manifest_name}"

    local dedup_key="${target_registry_url}::${LAST_PUSHED_DIGEST}"

    if test -n "${LAST_PUSHED_DIGEST}" && test "${_signed_digests["${dedup_key}"]+_}" = "_"; then
        echo "INFO: digest ${LAST_PUSHED_DIGEST} already signed for ${target_registry_url}; skipping sign of ${target_manifest_name}"
        return 0
    fi

    # Record digest only on sign success — a transient failure should not suppress retries
    # on subsequent tags for the same digest. Also skip recording when signing is disabled
    # (cosign_sign_image returns 0 but no signature is written).
    local sign_rc
    cosign_sign_image "${ref}" "${docker_config_dir}"
    sign_rc=${?}
    if test "${sign_rc}" -eq 0; then
        echo "Successfully signed manifest: ${ref}"
        test -n "${LAST_PUSHED_DIGEST}" &&
            test "${SIGNING_ENABLED:-true}" = "true" &&
            _signed_digests["${dedup_key}"]=1
    else
        echo_red "cosign sign failed for ${ref}"
        exit "${sign_rc}"
    fi
}

create_manifest_and_push() {
    local target_manifest_name="${1}"
    local ref="${target_registry_url}/${product_to_deploy}:${target_manifest_name}"

    # Word-split is expected behavior for $images_list. Disable shellcheck.
    # shellcheck disable=SC2086
    exec_cmd_or_fail docker --config "${docker_config_dir}" manifest create "${ref}" ${images_list}

    # $() subshell is limited to the push command only so that rc-check and exit
    # run in the main shell (fail-fast preserved). Do not wrap the whole function in $().
    local push_out
    push_out=$(docker --config "${docker_config_dir}" manifest push --purge "${ref}")
    local push_rc=${?}
    if test "${push_rc}" -ne 0; then
        echo_red "The following command resulted in an error: docker manifest push --purge ${ref}"
        exit "${push_rc}"
    fi

    echo "${push_out}"
    echo "Successfully created and pushed manifest: ${ref}"

    # Extract the pushed OCI index digest. grep | head exit status is intentionally ignored —
    # this script does not set pipefail. head -1 takes the pushed digest; --purge delete-
    # confirmation tokens appear after it. See pre-merge verification gate in PDI-2432.
    LAST_PUSHED_DIGEST=$(printf '%s\n' "${push_out}" | grep -Eo 'sha256:[0-9a-f]{64}' | head -1)
    test -z "${LAST_PUSHED_DIGEST}" &&
        echo_yellow "WARN: no sha256 digest found in push output for ${ref}; dedup signing guard disabled for this tag"
}

publish_manifest_to_redhat_registry() {
    target_manifest_name="${1}"
    # Redhat preflight binary filename
    preflight_filename="/usr/local/bin/preflight"

    # Set openshift project id
    if test "${product_to_deploy}" == "pingaccess"; then
        openshift_project_id="${PA_OPENSHIFT_PROJECT_ID}"
    elif test "${product_to_deploy}" == "pingfederate"; then
        openshift_project_id="${PF_OPENSHIFT_PROJECT_ID}"
    fi

    # Download Redhat's preflight tool
    if test ! -f "${preflight_filename}"; then
        echo "INFO: Downloading latest preflight version for Linux"

        # Download the latest version of preflight for linux amd64(x86_64) from GitHub.
        preflight_download_url=$(curl --silent https://api.github.com/repos/redhat-openshift-ecosystem/openshift-preflight/releases/latest | jq -r '.assets[] | select(.name|test("linux-amd64")) | .browser_download_url')
        test -z "${preflight_download_url}" && echo "Error: Failed to retrieve preflight download URL" && exit 1
        curl --location --silent --output "${preflight_filename}" "${preflight_download_url}"
        test $? -ne 0 && echo "Error: Failed to retrieve preflight binary from GitHub" && exit 1

        # Give execute permissions to shellcheck
        chmod +x "${preflight_filename}"
        test $? -ne 0 && echo "Error: Failed to exit execute permissions on preflight binary" && exit 1
    fi

    # Run preflight on redhat manifests
    echo "Running redhat preflight check on manifest: ${product_to_deploy}:${target_manifest_name}"
    exec_cmd_or_fail preflight check container "${DOCKER_HUB_REGISTRY}/${product_to_deploy}:${target_manifest_name}" --submit --certification-component-id="${openshift_project_id}" --docker-config="${docker_config_dir}/config.json" --pyxis-api-token="${PYXIS_API_TOKEN}"
    echo "Successfully pushed manifest: ${target_registry_url}/${product_to_deploy}:${target_manifest_name}"
}

while test -n "${1}"; do
    case "${1}" in
        -p | --product)
            shift
            test -z "${1}" && usage "You must provide a product to build"
            product_to_deploy="${1}"
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

test -z "${product_to_deploy}" &&
    usage "Specifying a product to deploy is required"

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
# shellcheck source=./cosign_sign.sh
. "${CI_SCRIPTS_DIR}/cosign_sign.sh"

# Grab the YYMM sprint tag from current commit if present
# If PIPELINE_VERSIONS_JSON_OVERRIDE is set, grab most recent
# tag on current git branch.
sprint="$(_getSprintTagIfAvailable)"

#Define docker config file locations based on different image registry providers
docker_config_hub_dir="$HOME/.docker-hub"
#docker_config_default_dir="$HOME/.docker"

# Tracks digests already signed this run to prevent duplicate cosign signatures
# when multiple tags resolve to the same OCI index digest.
declare -A _signed_digests=()
LAST_PUSHED_DIGEST=""

versions_to_deploy=$(_getAllVersionsToDeployForProduct "${product_to_deploy}")
latest_version=$(_getLatestVersionForProduct "${product_to_deploy}")

banner "Running deploy_manifests_to_registry for Product: ${product_to_deploy}"
for version in ${versions_to_deploy}; do
    shims_to_deploy=$(_getShimsToDeployForProductVersion "${product_to_deploy}" "${version}")
    default_shim=$(_getDefaultShimForProductVersion "${product_to_deploy}" "${version}")
    for shim in ${shims_to_deploy}; do
        shim_long_tag=$(_getLongTag "${shim}")
        jvms_to_deploy=$(_getJVMsToDeployForProductVersionShim "${product_to_deploy}" "${version}" "${shim}")
        default_jvm=$(_getPreferredJVMForProductVersionShim "${product_to_deploy}" "${version}" "${shim}")
        for jvm in ${jvms_to_deploy}; do
            registry_list=$(_getTargetRegistriesForProductVersionShimJVM "${product_to_deploy}" "${version}" "${shim}" "${jvm}")
            for target_registry in ${registry_list}; do
                target_registry=$(toLower "${target_registry}")
                case "${target_registry}" in
                    "artifactory")
                        # TODO Artifactory is using v1 manifests. Update this to use manifests in Artifactory
                        echo_yellow "Registry ${target_registry} is not implemented in deploy_manifests.sh"
                        # target_registry_url="${ARTIFACTORY_REGISTRY}"
                        # docker_config_dir="${docker_config_default_dir}"
                        # notary_server="https://notaryserver:4443"
                        continue
                        ;;
                    "dockerhub")
                        target_registry_url="${DOCKER_HUB_REGISTRY}"
                        docker_config_dir="${docker_config_hub_dir}"
                        ;;
                    "fedramp")
                        echo_yellow "Registry ${target_registry} is not implemented in deploy_manifests.sh"
                        continue
                        ;;
                    *)
                        echo_red "Registry ${target_registry} is not implemented in deploy_manifests.sh" && exit 1
                        ;;
                esac

                # Create a list of images that can be combined into a
                # multi-arch manifest for the provided product, shim, jvm, and version
                images_list=""
                banner "Verifying Images From ${target_registry} for: ${product_to_deploy} ${shim} ${jvm} ${version}"
                for arch in $(_getAllArchsForJVM "${jvm}"); do
                    current_image="${target_registry_url}/${product_to_deploy}:${version}-${shim_long_tag}-${jvm}-${arch}-edge"
                    #Verify the image exists on the target_registry
                    exec_cmd_or_fail docker --config "${docker_config_dir}" manifest inspect "${current_image}"
                    images_list="${images_list:+${images_list} }${current_image}"
                    echo "Image verified: ${current_image}"
                done # iterating over architectures

                #This builds pushes manifests to the target registry that contain the images in $images_list
                banner "Creating Multi-Arch Manifests in ${target_registry} for: ${product_to_deploy} ${shim} ${jvm} ${version}"
                if test -n "${PIPELINE_VERSIONS_JSON_OVERRIDE}"; then
                    create_manifest_and_push_and_sign "${sprint}-${version}"
                else
                    if test -n "${sprint}"; then
                        create_manifest_and_push_and_sign "${sprint}-${version}-${shim_long_tag}-${jvm}"
                        if [[ "${shim_long_tag}" == "redhat"* ]]; then
                            publish_manifest_to_redhat_registry "${sprint}-${version}-${shim_long_tag}-${jvm}"
                        else
                            create_manifest_and_push_and_sign "${version}-${shim_long_tag}-${jvm}-latest"
                        fi
                        if test "${shim}" = "${default_shim}" && test "${jvm}" = "${default_jvm}"; then
                            create_manifest_and_push_and_sign "${version}-latest"
                            create_manifest_and_push_and_sign "${sprint}-${version}"
                            if test "${version}" = "${latest_version}"; then
                                create_manifest_and_push_and_sign "latest"
                                create_manifest_and_push_and_sign "${sprint}"
                            fi
                        fi
                    fi
                    if test "${shim}" = "${default_shim}" && test "${jvm}" = "${default_jvm}"; then
                        create_manifest_and_push_and_sign "${version}-edge"
                        if test "${version}" = "${latest_version}"; then
                            create_manifest_and_push_and_sign "edge"
                        fi
                    fi
                    if [[ "${shim_long_tag}" != "redhat"* ]]; then
                        create_manifest_and_push_and_sign "${version}-${shim_long_tag}-${jvm}-edge"
                    fi
                fi

                # Delete images of type ${version}-${shim_long_tag}-${jvm}-${arch}-edge from target registry
                # These images are no longer needed, as they should be accessible in multi-arch manifest images formed above
                banner "Deleting Non-Multi-Arch Images in ${target_registry} for: ${product_to_deploy} ${shim} ${jvm} ${version}"
                case "${target_registry}" in
                    "dockerhub")
                        # Get Dockerhub Auth Token
                        http_response_code=$(curl --silent --request "POST" --write-out '%{http_code}' --output "/tmp/dockerhub.api.out" --header "Content-Type: application/json" --data '{"username": "'"${DOCKER_USERNAME}"'", "password": "'"${DOCKER_ACCESS_TOKEN}"'"}' "https://hub.docker.com/v2/users/login/")
                        if test "${http_response_code}" -eq 200; then
                            dockerhub_auth_token=$(jq -r .token "/tmp/dockerhub.api.out")
                            echo "Successfully Retrieved Login Auth Token from DockerHub"
                        else
                            echo_red "${http_response_code}: Unable to login to dockerhub for tag deletion" && exit 1
                        fi

                        # Loop through Architectures and delete images used to build manifests.
                        for arch in $(_getAllArchsForJVM "${jvm}"); do
                            http_response_code=$(curl --silent --request "DELETE" --write-out '%{http_code}' --output "/dev/null" --header "Authorization: Bearer ${dockerhub_auth_token}" "https://hub.docker.com/v2/repositories/pingidentity/${product_to_deploy}/tags/${version}-${shim_long_tag}-${jvm}-${arch}-edge")
                            if test "${http_response_code}" -eq 204; then
                                echo "Successfully deleted image tag: ${version}-${shim_long_tag}-${jvm}-${arch}-edge"
                            else
                                echo_red "${http_response_code}: Unable to delete image tag: ${version}-${shim_long_tag}-${jvm}-${arch}-edge" && exit 1
                            fi
                        done # iterating over architectures
                        ;;
                    *)
                        echo_yellow "Tag Deletion for Registry ${target_registry} is not implemented in deploy_manifests_to_registry.sh"
                        ;;
                esac
            done # iterating over target registries
        done     # iterating over JVMS
    done         # iterating over shims
done             # iterating over versions
exit 0
