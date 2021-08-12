#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# Utilities used across all CI scripts
#
test "${VERBOSE}" = "true" && set -x

HISTFILE=~/.bash_history
set -o history
HISTTIMEFORMAT='%T'
export HISTTIMEFORMAT

# get all versions (from versions.json) for a product to build
_getAllVersionsToBuildForProduct() {
    _jvmFilter=$(_getJVMFilterArray)
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]|[. as $v |.shims[]|.jvms[]|select(.build==true)|select(.jvm as $j|'"${_jvmFilter}"'|index($j))|$v.version]|unique|.[]' "${_file}"
}

# get all versions (from versions.json) for a product to deploy
_getAllVersionsToDeployForProduct() {
    _jvmFilter=$(_getJVMFilterArray)
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]|[. as $v |.shims[]|.jvms[]|select(.deploy==true)|select(.jvm as $j|'"${_jvmFilter}"'|index($j))|$v.version]|unique|.[]' "${_file}"
}

# get the latest (from versions.json) version of a product to build
_getLatestVersionForProduct() {
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r 'if (.latest) then .latest else "" end' "${_file}"
}

# get the default shim (from versions.json) for a product version
_getDefaultShimForProductVersion() {
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]| select(.version == "'"${2}"'") | .preferredShim' "${_file}"
}

# get all the shims (from versions.json) for a product version
_getShimsToBuildForProductVersion() {
    _jvmFilter=$(_getJVMFilterArray)
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '[.|.versions[]| select(.version == "'"${2}"'")|.shims[]|. as $v|.jvms[]|select(.build==true)|select(.jvm as $j|'"${_jvmFilter}"'|index($j))|$v.shim]|unique|.[]' "${_file}"
}

# get all shims for JVM
_getShimsToBuildForJVM() {
    _file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    test -f "${_file}" && jq -r '[.|.versions[]|select(.id=="'"${1}"'")|.shims[]]|unique|.[]' "${_file}"
}

# get all the shims (from versions.json) for a product version
_getShimsToDeployForProductVersion() {
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '[.|.versions[]| select(.version == "'"${2}"'")|.shims[]|. as $v|.jvms[]|select(.deploy==true)|$v.shim]|unique|.[]' "${_file}"
}

# get all the shims (from versions.json) for a product
_getAllShimsForProduct() {
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '[.|.versions[]|.shims[]|.shim]|unique|.[]' "${_file}"
}

# get all the jvms (from versions.json) for a product to build
_getJVMsToBuildForProductVersionShim() {
    _jvmFilter=$(_getJVMFilterArray)
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]|select(.version=="'"${2}"'").shims[]|select(.shim=="'"${3}"'")|.jvms[]|select(.build==true)|select(.jvm as $j|'"${_jvmFilter}"'|index($j))|.jvm' "${_file}"
}

_getJVMsForArch() {
    # treat as a singleton
    if test -z "${_JVMS}"; then
        _file="${CI_PROJECT_DIR}/pingjvm/versions.json"
        _JVMS=$(jq -r '[.versions[]|select(.archs[]|contains("'"${ARCH}"'"))|.id]|.[]' "${_file}")
        export _JVMS
    fi
    printf "%s" "${_JVMS}"
}

_getAllArchsForJVM() {
    _file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    test -f "${_file}" && jq -r '.versions[]|select(.id == "'"${1}"'")|.archs|.[]' "${_file}"
}

_isJVMMultiArch() {
    _file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    if test -f "${_file}"; then
        _numArchs=$(jq -r '.versions[]|select(.id == "'"${1}"'")|.archs|length' "${_file}")
        test "${_numArchs}" -gt 1 && return 0
    fi
    return 1
}

_getJVMFilterArray() {
    # treat as a singleton
    if test -z "${_JVM_FILTER_ARRAY}"; then
        for _j in $(_getJVMsForArch); do
            # shellcheck disable=SC2089
            _v=${_v}${_v:+,}'"'${_j}'"'
        done
        _JVM_FILTER_ARRAY="[${_v}]"
        # shellcheck disable=SC2090
        export _JVM_FILTER_ARRAY
    fi
    printf "%s" "${_JVM_FILTER_ARRAY}"
}

_filterJVMForArch() {
    _file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    test -f "${_file}" && jq -r '[.versions[]|select(.id=="'"${1}"'")|select(.archs[]|contains("'"${ARCH}"'"))|.id]|.[]' "${_file}"
}

# get all the jvms (from versions.json) for a product to deploy
_getJVMsToDeployForProductVersionShim() {
    _jvmFilter=$(_getJVMFilterArray)
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]|select(.version=="'"${2}"'").shims[]|select(.shim=="'"${3}"'")|.jvms[]|select(.deploy==true)|select(.jvm as $j|'"${_jvmFilter}"'|index($j))|.jvm' "${_file}"
}

# get the preferred (from versions.json) for a product, version and shim
_getPreferredJVMForProductVersionShim() {
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]|select(.version=="'"${2}"'").shims[]|select(.shim=="'"${3}"'")|.preferredJVM' "${_file}"
}

# get the target image registries for a product, version, shim, and jvm
_getTargetRegistriesForProductVersionShimJVM() {
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]|select(.version=="'"${2}"'").shims[]|select(.shim=="'"${3}"'")|.jvms[]|select(.jvm=="'"${4}"'")|.registries[]' "${_file}"
}

# get the jvm versions (from versions.json) for an ID
_getJVMVersionForID() {
    _file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]|select(.id=="'"${1}"'")|.version' "${_file}"
}

# get the jvm IDs (from versions.json) for a shim
_getAllJVMIDsForShim() {
    _file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    test -f "${_file}" && jq -r '[.versions[]|select(.archs[]|contains("'"${ARCH}"'"))|select(.shims[]|contains("'"${1}"'"))|.id]|unique|.[]' "${_file}"
}

# get the jvms (from versions.json) to build for a shim
_getAllJVMsToBuildForShim() {
    for _jvm in $(find "${CI_PROJECT_DIR}" -type f -not -path "${CI_PROJECT_DIR}/pingjvm/*" -name versions.json -exec jq -r '.|.versions[]|.shims[]|select(.shim=="'"${1}"'")|.jvms[]|select(.build==true)|.jvm' {} + 2> /dev/null | sort | uniq); do
        _filterJVMForArch "${_jvm}"
    done
}

# get the jvms (from versions.json) to build
_getAllJVMsToBuild() {
    find "${CI_PROJECT_DIR}" -type f -not -path "${CI_PROJECT_DIR}/pingjvm/*" -name versions.json -exec jq -r '.|.versions[]|.shims[]|.jvms[]|select(.build==true)|.jvm' {} + 2> /dev/null | sort | uniq
}

# get the jvm images (from versions.json) for a shim ID
_getJVMImageForShimID() {
    _file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    test -f "${_file}" && jq -r '[.versions[]|select(.shims[]|contains("'"${1}"'"))| select(.id=="'"${2}"'")|.from]|unique|.[]' "${_file}"
}

# get the dependencies (from versions.json) for product version
_getDependenciesForProductVersion() {
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -jr '.versions[]|select( .version == "'"${2}"'" )|if (.dependencies) then .dependencies[]|.product," ",.version,"\n" else "" end' "${_file}" | awk 'BEGIN{i=0} {print "--build-arg DEPENDENCY_"i"_PRODUCT="$1" --build-arg DEPENDENCY_"i"_VERSION="$2; i++}'
}

# get the long tag
_getLongTag() {
    echo "${1}" | awk '{gsub(/:/,"_");print}'
}

# get the short tag
_getShortTag() {
    echo "${1}" | awk '{gsub(/:.*/,"");print}'
}

# get the the shims (from versions.json)
_getAllShims() {
    find "${CI_PROJECT_DIR}" -type f -not -path "${CI_PROJECT_DIR}/pingjvm/*" -name versions.json -exec jq -r '[.|.versions[]|.shims[]|.shim]|unique|.[]' {} + 2> /dev/null | sort | uniq
}

# returns the license version from the full product version
#
# Example: 8.1.0.1 --> 8.1
_getLicenseVersion() {
    echo "${1}" | cut -d. -f1,2
}

###############################################################################
# get_value (variable)
#
# Get the value of a variable passed, preserving any spaces
###############################################################################
get_value() {
    # the following will preserve spaces in the printf
    IFS="%%"
    eval printf '%s' "\${${1}}"
    unset IFS
}

# echos banner bar of 80 hashes '#'
banner_bar() {
    printf '%0.1s' "#"{1..80}
    printf "\n"
}

banner_pad=$(printf '%0.1s' " "{1..80})
# echos banner contents centering argument passed
banner_head() {
    # line is divided like so # <- a -> b <- c ->#
    # b is the string to display centered
    # a and c are whitespace padding to center the string
    _b="${*}"
    if test ${#_b} -gt 78; then
        _a=0
        _c=0
    else
        _a=$(((78 - ${#_b}) / 2))
        _c=$((78 - _a - ${#_b}))
    fi
    printf "#"
    printf '%*.*s' 0 ${_a} "${banner_pad}"
    printf "%s" "${_b}"
    printf '%*.*s' 0 ${_c} "${banner_pad}"
    printf "#\n"
}

# echos full banner with contents
banner() {
    banner_bar
    banner_head "${*}"
    banner_bar
}

FONT_RED="$(printf '\033[0;31m')"
FONT_GREEN="$(printf '\033[0;32m')"
FONT_YELLOW="$(printf '\033[0;33m')"
FONT_NORMAL="$(printf '\033[0m')"
CHAR_CHECKMARK="$(printf '\xE2\x9C\x94')"
CHAR_CROSSMARK="$(printf '\xE2\x9D\x8C')"

################################################################################
# Echo message in red color
################################################################################
echo_red() {
    echo "${FONT_RED}$*${FONT_NORMAL}"
}

################################################################################
# Echo message in yellow color
################################################################################
echo_yellow() {
    echo "${FONT_YELLOW}$*${FONT_NORMAL}"
}

################################################################################
# Echo message in green color
################################################################################
echo_green() {
    echo "${FONT_GREEN}$*${FONT_NORMAL}"
}

################################################################################
# Return input in lowercase
################################################################################
toLower() {
    printf "%s" "${*}" | tr '[:upper:]' '[:lower:]'
}

################################################################################
# append to output following a colorized pattern
################################################################################
append_status() {
    _output="${1}"
    shift
    if test "${1}" = "PASS"; then
        _prefix="${FONT_GREEN}${CHAR_CHECKMARK} "
    else
        _prefix="${FONT_RED}${CHAR_CROSSMARK} "
    fi
    shift
    _pattern="${1}"
    shift
    #As the _pattern and # of inputs is undefined here, it is not easy/reasonable to follow SC2059
    # shellcheck disable=SC2059
    printf "${_prefix}${_pattern}${FONT_NORMAL}\n" "${@}" >> "${_output}"

}

################################################################################
# Convenience function for curl
################################################################################
_curl() {
    curl \
        --get \
        --silent \
        --show-error \
        --location \
        --connect-timeout 2 \
        --retry 6 \
        --retry-max-time 30 \
        --retry-connrefused \
        --retry-delay 3 \
        "${@}"
    return ${?}
}

################################################################################
# get the latest snapshot version for a product
#
# currently only available for the Ping Data products
################################################################################
_getLatestSnapshotVersionForProduct() {
    _baseURL="${SNAPSHOT_NEXUS_URL}"
    _basePath="com/unboundid/product/ds"
    case "${1}" in
        pingdirectory)
            _product="directory"
            ;;
        pingdirectoryproxy)
            _product="proxy"
            ;;
        pingdatasync)
            _product="sync"
            ;;
        pingdatagovernance | pingauthorize)
            _product="broker"
            ;;
        pingdatagovernancepap | pingauthorizepap)
            _product="symphonic-pap-packaged"
            _basePath="com/pingidentity/pd/governance"
            ;;
        *) ;;

    esac
    case "${1}" in
        pingdatagovernance | pingdatagovernancepap | pingdatasync | pingdirectory | pingdirectoryproxy | pingauthorize | pingauthorizepap)
            _curl "${_baseURL}/${_basePath}/${_product}/maven-metadata.xml" | xmllint --xpath 'string(/metadata/versioning/latest)' -
            ;;
        pingdelegator)
            _curl "${SNAPSHOT_DELEGATOR_URL}/maven-metadata.xml" | xmllint --xpath 'string(/metadata/versioning/snapshotVersions/snapshotVersion/value)' -
            ;;
        pingcentral)
            _curl "${SNAPSHOT_ARTIFACTORY_URL}/pass/pass-common/maven-metadata.xml" | sed -e 's/xmlns=".*"//g' | xmllint --xpath 'string(/metadata/versioning/latest)' -
            ;;
        pingfederate)
            _curl "${SNAPSHOT_BLD_FED_URL}/artifact/pf-server/HuronPeak/assembly/pom.xml" | sed -e 's/xmlns=".*"//g' | xmllint --xpath 'string(/project/version)' -
            ;;
        pingaccess)
            _curl "${SNAPSHOT_ARTIFACTORY_URL}/products/pingaccess/maven-metadata.xml" | sed -e 's/xmlns=".*"//g' | xmllint --xpath 'string(/metadata/versioning/latest)' -
            ;;
    esac
    return ${?}
}

################################################################################
# Verify that the file is found.  If not, then error/exit
################################################################################
requirePipelineFile() {
    _pipelineFile="$(get_value "${1}")"

    if test ! -f "${_pipelineFile}"; then
        echo_red "${_pipelineFile} file missing. Needs to be defined/created (i.e. ci/cd pipeline file)"
        exit 1
    fi
}

################################################################################
# Verify that the variable is found and not empty.  If not, then error/exit
################################################################################
requirePipelineVar() {
    _pipelineVar="${1}"

    if test -z "${_pipelineVar}"; then
        echo_red "${_pipelineVar} variable missing. Needs to be defined/created (i.e. ci/cd pipeline variable)"
        exit 1
    fi
}

################################################################################
# This function does the following:
# 1) Perform a docker login to docker hub.  This is required to properly authenticate and
# sign images with docker as well as avoid rate limiting from Dockers new policies.
# 2) Bring in the docker config.json for all other registries. Provides instructions to docker on how to
# authenticate to docker registries.
################################################################################
setupDockerConfigJson() {
    ####### SET UP DOCKERHUB #######
    echo "Logging Into DockerHub..."
    requirePipelineVar DOCKER_USERNAME
    requirePipelineVar DOCKER_PASSWORD
    requirePipelineVar DOCKER_HUB_REGISTRY
    mkdir -p "${docker_config_hub_dir}"

    # login to docker.io to create the docker hub config.json
    docker --config "${docker_config_hub_dir}" login --username "${DOCKER_USERNAME}" --password "${DOCKER_PASSWORD}"
    test ${?} -ne 0 && echo_red "Error: Failed to login to DockerHub in ci_tools.sh" && exit 1

    ####### SET UP ALL OTHER REGISTRIES #######
    # Ensure that the pipe-line provides the following variables/files
    requirePipelineVar PIPELINE_BUILD_REGISTRY_VENDOR
    requirePipelineVar PIPELINE_BUILD_REGISTRY
    requirePipelineVar PIPELINE_BUILD_REPO
    requirePipelineVar ARTIFACTORY_REGISTRY
    requirePipelineVar FEDRAMP_REGISTRY
    requirePipelineFile DOCKER_CONFIG_JSON

    echo "Using Docker config.json '${DOCKER_CONFIG_JSON}'"
    mkdir -p "${docker_config_default_dir}"
    cp "${DOCKER_CONFIG_JSON}" "${docker_config_default_dir}/config.json"

    # In order to initialize the docker login to ecr, a single docker pull needs
    # to occur.  This basically primes the pump for docker builds with FROMs later on
    docker --config "${docker_config_default_dir}" pull "${PIPELINE_BUILD_REGISTRY}/ci-utils/hello:latest"
}

#Define docker config file locations based on different image registry providers
docker_config_hub_dir="/root/.docker-hub"
docker_config_default_dir="/root/.docker"

if test -n "${PING_IDENTITY_SNAPSHOT}"; then
    #we are in building snapshot
    FOUNDATION_REGISTRY="${PIPELINE_BUILD_REGISTRY}/${PIPELINE_BUILD_REPO}"
    # we terminate to DEPS registry with a slash so it can be omitted to revert to implicit
    DEPS_REGISTRY="${PIPELINE_DEPS_REGISTRY}/"

    banner "CI PIPELINE using ${PIPELINE_BUILD_REGISTRY_VENDOR} - ${FOUNDATION_REGISTRY}"

    #
    # setup the docker config.json.
    #
    setupDockerConfigJson

    GIT_REV_SHORT=$(date '+%H%M')
    GIT_REV_LONG=$(date '+%s')
    CI_TAG="$(date '+%Y%m%d')"
elif test -n "${CI_COMMIT_REF_NAME}"; then
    #we are in CI pipeline
    FOUNDATION_REGISTRY="${PIPELINE_BUILD_REGISTRY}/${PIPELINE_BUILD_REPO}"
    # we terminate to DEPS registry with a slash so it can be omitted to revert to implicit
    DEPS_REGISTRY="${PIPELINE_DEPS_REGISTRY}/"

    banner "CI PIPELINE using ${PIPELINE_BUILD_REGISTRY_VENDOR} - ${FOUNDATION_REGISTRY}"

    #
    # setup the docker config.json.
    #
    setupDockerConfigJson

    case "${PIPELINE_BUILD_REGISTRY_VENDOR}" in
        aws)
            # shellcheck source=./aws_tools.lib.sh
            . "${CI_SCRIPTS_DIR}/aws_tools.lib.sh"
            ;;
        google)
            # shellcheck source=./google_tools.lib.sh
            . "${CI_SCRIPTS_DIR}/google_tools.lib.sh"
            ;;
        azure)
            echo_red "azure not implemented yet"
            exit 1
            # shellcheck source=./azure_tools.lib.sh
            . "${CI_SCRIPTS_DIR}/azure_tools.lib.sh"
            ;;
    esac

    #
    # setup the docker trust material.
    #
    requirePipelineFile DOCKER_TRUST_PRIVATE_KEY_ARCHIVE_FILE
    requirePipelineVar DOCKER_TRUST_PRIVATE_KEY
    requirePipelineVar DOCKER_TRUST_PRIVATE_KEY_SIGNER

    #Use private key file with DockerHub
    mkdir -p "${docker_config_hub_dir}/trust/private"
    (cd "${docker_config_hub_dir}/trust/private" && base64 --decode "${DOCKER_TRUST_PRIVATE_KEY_ARCHIVE_FILE}" | tar -xz)
    docker --config "${docker_config_hub_dir}" trust key load "${docker_config_hub_dir}/trust/private/${DOCKER_TRUST_PRIVATE_KEY}" --name "${DOCKER_TRUST_PRIVATE_KEY_SIGNER}"

    #Use private key file with Artifactory
    mkdir -p "${docker_config_default_dir}/trust/private"
    (cd "${docker_config_default_dir}/trust/private" && base64 --decode "${DOCKER_TRUST_PRIVATE_KEY_ARCHIVE_FILE}" | tar -xz)
    docker --config "${docker_config_default_dir}" trust key load "${docker_config_default_dir}/trust/private/${DOCKER_TRUST_PRIVATE_KEY}" --name "${DOCKER_TRUST_PRIVATE_KEY_SIGNER}"

    #Provide Root CA Certificate for Artifactory Notary Server
    requirePipelineFile ARTIFACTORY_ROOT_CA_FILE
    echo "Using root CA certificate file'${ARTIFACTORY_ROOT_CA_FILE}'"
    cp "${ARTIFACTORY_ROOT_CA_FILE}" "/usr/local/share/ca-certificates/root-ca.crt"
    update-ca-certificates

    requirePipelineVar ARTIFACTORY_NOTARY_SERVER_IP
    echo "Using notary server IP value'${ARTIFACTORY_NOTARY_SERVER_IP}'"
    echo "${ARTIFACTORY_NOTARY_SERVER_IP} notaryserver" >> /etc/hosts

    GIT_REV_SHORT=$(git rev-parse --short=4 "$CI_COMMIT_SHA")
    GIT_REV_LONG=$(git rev-parse "$CI_COMMIT_SHA")
    CI_TAG="${CI_COMMIT_REF_NAME}-${CI_COMMIT_SHORT_SHA}"
else
    #we are on local
    IS_LOCAL_BUILD=true
    export IS_LOCAL_BUILD
    FOUNDATION_REGISTRY="pingidentity"
    DEPS_REGISTRY="${DEPS_REGISTRY_OVERRIDE}"
    gitBranch=$(git rev-parse --abbrev-ref HEAD)
    GIT_REV_SHORT=$(git rev-parse --short=4 HEAD)
    GIT_REV_LONG=$(git rev-parse HEAD)
    CI_TAG="${gitBranch}-${GIT_REV_SHORT}"
fi
ARCH="$(uname -m)"
export ARCH
export FOUNDATION_REGISTRY
export DEPS_REGISTRY
export GIT_REV_SHORT
export GIT_REV_LONG
export gitBranch
export CI_TAG
