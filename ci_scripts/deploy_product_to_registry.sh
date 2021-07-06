#!/usr/bin/env sh
#
# Ping Identity DevOps - CI scripts
#
# This script deploys products to registries based on the
# registries listed in the product's versions.json file
#
test "${VERBOSE}" = "true" && set -x

# Usage printing function
usage() {
    cat << END_USAGE
Usage: ${0} {options}
    where {options} include:

    -p, --product
        The name of the product for which to deploy docker images
    --dry-run
        does everything except actually call the docker command and prints it instead
    --help
        Display general usage information
END_USAGE
    test -n "${*}" && echo "${*}"
    exit 99
}

# Executes the command passed, and fails if return code ne 0
exec_cmd_or_fail() {
    eval "${dry_run} ${*}"
    result_code=${?}
    test "${result_code}" -ne 0 && echo_red "The following command resulted in an error: ${*}" && exit "${result_code}"
}

# Tags the product being deployed and push into registry
tag_and_push() {
    case "${target_registry}" in
        "artifactory")
            target_registry_url="${ARTIFACTORY_REGISTRY}"
            ;;
        "dockerhub")
            target_registry_url="${DOCKER_HUB_REGISTRY}"
            ;;
        *)
            target_registry_url="${target_registry}"
            ;;
    esac

    target_tag="${1}"
    source="${FOUNDATION_REGISTRY}/${product_to_deploy}:${full_tag}"
    target="${target_registry_url}/${product_to_deploy}:${target_tag}"

    echo "Function tag_and_push() is deploying ${target}"
    if test -z "${IS_LOCAL_BUILD}"; then
        #Use Docker Content Trust to Sign and push images to a specified registry
        if test -z "${DEPLOY_NO_PUSH}"; then
            exec_cmd_or_fail docker tag "${source}" "${target}"
            case "${target_registry}" in
                "artifactory")
                    export DOCKER_CONTENT_TRUST_SERVER="https://notaryserver:4443"
                    docker --config "${docker_config_artifactory_dir}" trust revoke --yes "${target}"
                    exec_cmd_or_fail docker --config "${docker_config_artifactory_dir}" trust sign "${target}"
                    unset DOCKER_CONTENT_TRUST_SERVER
                    ;;
                "dockerhub")
                    #Check to see if signature data already exists for tag
                    #If it does, remove the signature data
                    tag_index=$(printf '%s' "${signed_tags}" | jq ". | index(\"${target_tag}\")")
                    if test "${tag_index}" != "null"; then
                        exec_cmd_or_fail docker --config "${docker_config_hub_dir}" trust revoke --yes "${target}"
                    fi
                    exec_cmd_or_fail docker --config "${docker_config_hub_dir}" trust sign "${target}"
                    ;;
                *)
                    #target registry not recognized, default to simple docker push.
                    echo_yellow "Non-default registry ${target_registry} -- Defaulting to unsigned docker push"
                    exec_cmd_or_fail docker push "${target}"
                    ;;
            esac
            exec_cmd_or_fail docker image rm -f "${target}"
        fi
    fi
}

while test -n "${1}"; do
    case "${1}" in
        -p | --product)
            shift
            test -z "${1}" && usage "You must provide a product to build"
            product_to_deploy="${1}"
            ;;
        --dry-run)
            dry_run="echo"
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

#Define docker config file locations based on different image registry providers
docker_config_hub_dir="/root/.docker-hub"
docker_config_ecr_dir="/root/.docker"
docker_config_artifactory_dir="/root/.docker-artifactory"

#Pull down Docker Trust JSON on signature data
signed_tags=$(docker trust inspect "${DOCKER_HUB_REGISTRY}/${product_to_deploy}" | jq "[.[0].SignedTags[].SignedTag]")

versions_to_deploy=$(_getAllVersionsToDeployForProduct "${product_to_deploy}")
banner "Deploying ${product_to_deploy}"
for version in ${versions_to_deploy}; do
    shims_to_deploy=$(_getShimsToDeployForProductVersion "${product_to_deploy}" "${version}")
    for shim in ${shims_to_deploy}; do
        shim_long_tag=$(_getLongTag "${shim}")
        jvms_to_deploy=$(_getJVMsToDeployForProductVersionShim "${product_to_deploy}" "${version}" "${shim}")
        for jvm in ${jvms_to_deploy}; do
            #Get the target registries for the specified product, version, shim, and jvm
            registry_list=$(_getTargetRegistriesForProductVersionShimJVM "${product_to_deploy}" "${version}" "${shim}" "${jvm}")
            for arch in $(_getAllArchsForJVM "${jvm}"); do
                banner "Processing ${product_to_deploy} ${shim} ${jvm} ${version} ${arch}"
                full_tag="${version}-${shim_long_tag}-${jvm}-${CI_TAG}-${arch}"
                test -z "${dry_run}" &&
                    docker --config "${docker_config_ecr_dir}" pull "${FOUNDATION_REGISTRY}/${product_to_deploy}:${full_tag}"
                for target_registry in ${registry_list}; do
                    target_registry=$(toLower "${target_registry}")
                    banner "Publishing ${product_to_deploy} ${shim} ${jvm} ${version} to ${target_registry}"
                    tag_and_push "${version}-${shim_long_tag}-${jvm}-${arch}-edge"
                done # iterating over target registries to deploy to
                test -z "${dry_run}" &&
                    docker image rm -f "${FOUNDATION_REGISTRY}/${product_to_deploy}:${full_tag}"
            done # iterating over architectures
        done     # iterating over JVMS
    done         # iterating over shims
done             # iterating over versions
exit 0
