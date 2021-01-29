#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# This script deploys products to registries based on the registries.json
#
test -n "${VERBOSE}" && set -x

#
# Usage printing function
#
usage ()
{
cat <<END_USAGE
Usage: ${0} {options}
    where {options} include:

    -r, --registry
        The registry to deploy new image tags to (may be specified multiple times)
        May also set variable DEPLOY_REGISTRY
    -l, --registry-file
        The file with the list of registries to deploy to (must be provided if --registry is omitted)
        May also set variable DEPLOY_REGISTRY_FILE
    * -p, --product
        The name of the product for which to build a docker image
    -v, --version
        the version of the product for which to build a docker image
        this setting overrides the versions in the version file of the target product
    -s, --shim
        the name of the operating system shim for which to build a docker image
    -d, --default-shim
        the name of the operating system shim to consider default and override metadata
    -j, --jvm
        the id of the jvm to deploy
    -J, --default-jvm
        the id of the jvm to consider default and override metadata
    --dry-run
        does everything except actually call the docker command and prints it instead
    --help
        Display general usage information

    Either --registry or --registry-file MUST be provided
END_USAGE
    test -n "${*}" && echo "${*}"
    exit 99
}

#
# Executes the command passed, and fails if return code ne 1
#
exec_cmd_fail ()
{
    eval "${dryRun} $*"

    test $? -ne 0 && echo "Error: $*" && exit 1
}

#
# Tags the product being deployed and push into registry
#
tag_and_push ()
{
    #
    # Special case for pingdownloader since it only has a tag for the branch and short sha
    #
    if test "${productToDeploy}" = "pingdownloader"
    then
        _target_tag="latest"
        _source="${FOUNDATION_REGISTRY}/pingdownloader:${CI_COMMIT_REF_NAME}-${CI_COMMIT_SHORT_SHA}"
        _target="${targetRegistry}/pingdownloader:${_target_tag}"
    else
        _target_tag="${1}"
        _source="${FOUNDATION_REGISTRY}/${productToDeploy}:${fullTag}"
        _target="${targetRegistry}/${productToDeploy}:${_target_tag}"
    fi

    test -z "${dryRun}" \
        && docker tag "${_source}" "${_target}"
    if test -z "${isLocalBuild}"
    then
        echo "Pushing ${_target}"
        #DOCKER_HUB_REGISTRY and ARTIFACTORY_REGISTRY are pipeline vars
        #Use Docker Content Trust to Sign and push images to a specified registry
        case "${targetRegistry}" in
            $DOCKER_HUB_REGISTRY)
                #Check to see if signature data already exists for tag
                #If it does, remove the signature data
                _tag_index=$(jq ". | index(\"${_target_tag}\")" <<< "${_signed_tags}")
                if test "${_tag_index}" != "null"
                then
                    docker --config "${_docker_config_hub_dir}" trust revoke --yes "${_target}"
                fi
                docker --config "${_docker_config_hub_dir}" trust sign "${_target}"
                ;;
            $ARTIFACTORY_REGISTRY)
                export DOCKER_CONTENT_TRUST_SERVER="https://notaryserver:4443"
                docker --config "${_docker_config_artifactory_dir}" trust revoke --yes "${_target}"
                docker --config "${_docker_config_artifactory_dir}" trust sign "${_target}"
                unset DOCKER_CONTENT_TRUST_SERVER
                ;;
            *)
                echo_red "ERROR: Registry to Deploy To Not Recognized For: ${targetRegistry}"
                echo_red " -- Defaulting to unsigned docker push"
                docker push "${_target}"
        esac

        docker image rm -f "${_target}"
    else
        echo "${_target}"
    fi
}

_registryList="${DEPLOY_REGISTRY}"
_registryListFile="${DEPLOY_REGISTRY_FILE}"
while test -n "${1}"
do
    case "${1}" in
        -p|--product)
            shift
            test -z "${1}" && usage "You must provide a product to build"
            productToDeploy="${1}"
            ;;
        -r|--registry)
            shift
            test -z "${1}" && usage "You must provide a registry"
            # targetRegistry=${1}
            _registryList="${_registryList:+${_registryList} }${1}"
            ;;
        -l|--registry-file)
            shift
            test -z "${1}" && usage "You must provide a registry file"
            test -f "${1}" || usage "The registry file provided does not exist or is not a file"
            _registryListFile="${1}"
            ;;
        -j|--jvm)
            shift
            test -z "${1}" && usage "You must provide a JVM id"
            jvmsToDeploy="${jvmsToDeploy:+${jvmsToDeploy} }${1}"
            ;;
        -J|--default-jvm)
            shift
            test -z "${1}" && usage "You must provide a JVM id"
            defaultJvm="${1}"
            ;;
        -s|--shim)
            shift
            test -z "${1}" && usage "You must provide an OS Shim"
            shimsToDeploy="${shimsToDeploy:+${shimsToDeploy} }${1}"
            ;;
        -d|--default-shim)
            shift
            test -z "${1}" && usage "You must provide a default OS Shim"
            defaultShim="${1}"
            ;;
        -v|--version)
            shift
            test -z "${1}" && usage "You must provide a version to build"
            versionsToDeploy="${versionsToDeploy:+${versionsToDeploy} }${1}"
            ;;
        --dry-run)
            dryRun="echo"
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

#
# read in the lines from the passed registry file
#
if test -f "${_registryListFile}" ; then
    while read -r _registry
    do
        if test -n "${_registry}"
        then
            _registryList="${_registryList:+${_registryList} }${_registry}"
        fi
    done < "${_registryListFile}"
fi

# _commitHasTags=$( git tag --points-at "${CI_COMMIT_SHA}" )
# _commitBranch=$( git branch --contains "${CI_COMMIT_SHA}" )
# test -z "${dryRun}" \
#     && test -z "${_commitHasTags}" \
#     && test "${_commitBranch}" != "* master" \
#     && echo "ERROR: are you sure this script should be running??" \
#     && exit 1

test -z "${_registryList}" \
    && usage "Specifying a registry to deploy to is required (You may set variables DEPLOY_REGISTRY or DEPLOY_REGISTRY_FILE)"
test -z "${productToDeploy}" \
    && usage "Specifying a product to deploy is required"

if test -z "${CI_COMMIT_REF_NAME}"
then
    CI_PROJECT_DIR="$( cd "$( dirname "${0}" )/.." || exit 97 ; pwd )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

banner "Deploying to registry(s) '${_registryListFile}'"

if test -z "${versionsToDeploy}"
then
    versionsToDeploy=$( _getAllVersionsToDeployForProduct "${productToDeploy}" )
fi
latestVersion=$( _getLatestVersionForProduct "${productToDeploy}" )

#
# Determine whether the commit is associated with a sprint tag
#   a print tag ends with 4 digits, YYMM
#
for tag in $( git tag --points-at "$gitRevLong" )
do
    # if test -z "$( echo ${tag} | sed 's/^[0-9]\{4\}$//' )"
    if test -z "${tag##2[0-9][0-9][0-9]*}"
    then
        sprint="${tag}"
        break
    fi
done

#Define docker config file locations based on different image registry providers
_docker_config_hub_dir="/root/.docker-hub"
_docker_config_ecr_dir="/root/.docker"
_docker_config_artifactory_dir="/root/.docker-artifactory"

#Pull down Docker Trust JSON on signature data
_signed_tags=$( docker trust inspect "${DOCKER_HUB_REGISTRY}/${productToDeploy}" | jq "[.[0].SignedTags[].SignedTag]" )

# _dateStamp=$( date '%y%m%d')
banner "Deploying ${productToDeploy}"

#
# Special case for pingdownloader, as it doesn't have versions to deploy
#
if test "${productToDeploy}" = "pingdownloader"
then
    test -z "${dryRun}" \
                && docker --config "${_docker_config_ecr_dir}" pull "${FOUNDATION_REGISTRY}/pingdownloader:${CI_COMMIT_REF_NAME}-${CI_COMMIT_SHORT_SHA}"
    for targetRegistry in ${_registryList}
    do
        tag_and_push ""
    done
    exit 0
fi

#
# For all other products with versions
#
for _version in ${versionsToDeploy}
do
    if test -z "${shimsToDeploy}"
    then
        _shimsToDeploy=$( _getShimsToDeployForProductVersion "${productToDeploy}" "${_version}" )
    else
        _shimsToDeploy=${shimsToDeploy}
    fi
    if test -z "${defaultShim}"
    then
        defaultShim=$( _getDefaultShimForProductVersion "${productToDeploy}" "${_version}" )
    fi
    for _shim in ${_shimsToDeploy}
    do
        _shimLongTag=$( _getLongTag "${_shim}" )
        fullTag="${_version}-${_shimLongTag}-${ciTag}"

        if test -z "${jvmsToDeploy}"
        then
            _jvmsToBuild=$( _getJVMsToDeployForProductVersionShim "${productToDeploy}" "${_version}" "${_shim}" )
        else
            _jvmsToBuild=${jvmsToDeploy}
        fi

        if test -z "${defaultJvm}"
        then
            defaultJvm=$( _getPreferredJVMForProductVersionShim "${productToDeploy}" "${_version}" "${_shim}" )
        fi

        for _jvm in ${_jvmsToBuild}
        do
            banner "Processing ${productToDeploy} ${_shim} ${_jvm} ${_version}"
            fullTag="${_version}-${_shimLongTag}-${_jvm}-${ciTag}"
            test -z "${dryRun}" \
                && docker --config "${_docker_config_ecr_dir}" pull "${FOUNDATION_REGISTRY}/${productToDeploy}:${fullTag}"
            # _jvmVersion=$( _getJVMVersionForID "${_jvm}" )
            for targetRegistry in ${_registryList}
            do
                # tag_and_push "${_version}-${_shimLongTag}-java${_jvmVersion}-edge"
                if test -n "${sprint}"
                then
                    # tag_and_push "${sprint}-${_shimLongTag}-${_version}"
                    # if test "${_version}" = "${latestVersion}"
                    # then
                        # tag_and_push "${sprint}-${_shimLongTag}-latest"
                        # tag_and_push "${_shimLongTag}-latest"
                    # fi

                    if test "${_shim}" = "${defaultShim}"
                    then
                        tag_and_push "${sprint}-${_version}"
                        tag_and_push "${_version}-latest"
                        tag_and_push "${_version}"

                        #if it's latest product version and a sprint, then it's "latest" overall and also just "edge".
                        if test "${_version}" = "${latestVersion}"
                        then
                            tag_and_push "latest"
                            tag_and_push "${sprint}"
                        fi
                    fi
                fi

                if test "${_jvm}" = "${defaultJvm}"
                then
                    # tag_and_push "${_version}-${_shimLongTag}-edge"
                    if test "${_shim}" = "${defaultShim}"
                    then
                        tag_and_push "${_version}-edge"
                        if test "${_version}" = "${latestVersion}"
                        then
                            tag_and_push "edge"
                        fi
                    fi
                fi
            done
            test -z "${dryRun}" \
                && docker image rm -f "${FOUNDATION_REGISTRY}/${productToDeploy}:${fullTag}"
        done
    done
done
exit 0