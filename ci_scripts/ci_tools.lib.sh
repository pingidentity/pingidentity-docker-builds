#!/usr/bin/env bash
# Copyright © 2025 Ping Identity Corporation

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

_getIntTestArch() {
    test -z "${1}" && echo_red "ERROR: The function _getIntTestArch requires a test name." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getIntTestArch requires a variation id." && exit 1

    tests_json="${CI_PROJECT_DIR}/helm-tests/integration-tests/integration-tests.json"

    # Ensure that the file exists before returning the file path.
    ! test -f "${tests_json}" && echo_red "ERROR: File ${tests_json} not found." && exit 1

    jq -r --arg testName "${1}" \
        --arg variationId "${2}" \
        '.tests[] | select(.name == $testName) | .variations[] | select(.id == $variationId) | .architecture' \
        "${tests_json}"
}

_getIntTestPlatform() {
    test -z "${1}" && echo_red "ERROR: The function _getIntTestPlatform requires a test name." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getIntTestPlatform requires a variation id." && exit 1

    tests_json="${CI_PROJECT_DIR}/helm-tests/integration-tests/integration-tests.json"

    # Ensure that the file exists before returning the file path.
    ! test -f "${tests_json}" && echo_red "ERROR: File ${tests_json} not found." && exit 1

    jq -r --arg testName "${1}" \
        --arg variationId "${2}" \
        '.tests[] | select(.name == $testName) | .variations[] | select(.id == $variationId) | .platform' \
        "${tests_json}"
}

_getIntTestProducts() {
    test -z "${1}" && echo_red "ERROR: The function _getIntTestProducts requires a test name." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getIntTestProducts requires a variation id." && exit 1

    tests_json="${CI_PROJECT_DIR}/helm-tests/integration-tests/integration-tests.json"

    # Ensure that the file exists before returning the file path.
    ! test -f "${tests_json}" && echo_red "ERROR: File ${tests_json} not found." && exit 1

    jq -r --arg testName "${1}" \
        --arg variationId "${2}" \
        '[.tests[] | select(.name == $testName) | .variations[] | select(.id == $variationId) | .products[] | .productName] | unique | .[]' \
        "${tests_json}"
}

_getIntTestProductJVM() {
    test -z "${1}" && echo_red "ERROR: The function _getIntTestProductJVM requires a test name." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getIntTestProductJVM requires a variation id." && exit 1
    test -z "${3}" && echo_red "ERROR: The function _getIntTestProductJVM requires a product name." && exit 1

    tests_json="${CI_PROJECT_DIR}/helm-tests/integration-tests/integration-tests.json"

    # Ensure that the file exists before returning the file path.
    ! test -f "${tests_json}" && echo_red "ERROR: File ${tests_json} not found." && exit 1

    jq -r --arg testName "${1}" \
        --arg variationId "${2}" \
        --arg prodName "${3}" \
        '.tests[] | select(.name == $testName) | .variations[] | select(.id == $variationId) | .products[] | select(.productName == $prodName) | .jvm' \
        "${tests_json}"
}

_getIntTestProductShim() {
    test -z "${1}" && echo_red "ERROR: The function _getIntTestProductShim requires a test name." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getIntTestProductShim requires a variation id." && exit 1
    test -z "${3}" && echo_red "ERROR: The function _getIntTestProductShim requires a product name." && exit 1

    tests_json="${CI_PROJECT_DIR}/helm-tests/integration-tests/integration-tests.json"

    # Ensure that the file exists before returning the file path.
    ! test -f "${tests_json}" && echo_red "ERROR: File ${tests_json} not found." && exit 1

    jq -r --arg testName "${1}" \
        --arg variationId "${2}" \
        --arg prodName "${3}" \
        '.tests[] | select(.name == $testName) | .variations[] | select(.id == $variationId) | .products[] | select(.productName == $prodName) | .shim' \
        "${tests_json}"
}

_getIntTestProductVersion() {
    test -z "${1}" && echo_red "ERROR: The function _getIntTestProductVersion requires a test name." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getIntTestProductVersion requires a variation id." && exit 1
    test -z "${3}" && echo_red "ERROR: The function _getIntTestProductVersion requires a product name." && exit 1

    tests_json="${CI_PROJECT_DIR}/helm-tests/integration-tests/integration-tests.json"

    # Ensure that the file exists before returning the file path.
    ! test -f "${tests_json}" && echo_red "ERROR: File ${tests_json} not found." && exit 1

    jq -r --arg testName "${1}" \
        --arg variationId "${2}" \
        --arg prodName "${3}" \
        '.tests[] | select(.name == $testName) | .variations[] | select(.id == $variationId) | .products[] | select(.productName == $prodName) | .version' \
        "${tests_json}"
}

# Retrieve the tag on the commit, or the most recent tag for the branch.
# If PIPELINE_VERSIONS_JSON_OVERRIDE is set, strongly validate YYMM format
# as well as validate the tag is 2201 or newer.
_getSprintTagIfAvailable() {
    # Determine whether the commit is associated with a sprint tag
    # A sprint tag is contains exactly 4 digits in a row, either YYMM or YYMM.X
    # A sprint tag in the docker-builds repository should not contain any letters
    for tag in $(git tag --points-at "${GIT_REV_LONG}"); do
        if test "${tag##[0-9][0-9][0-9][0-9]}" != "${tag}" && test "${tag##[A-Za-z]}" = "${tag}"; then
            sprint="${tag}"
            break
        fi
    done

    # If PIPELINE_VERSIONS_JSON_OVERRIDE is set and a sprint tag does not point at the current commit,
    # grab the most recent sprint tag of the current branch
    # Then verify it is a sprint version that supports versions.json override.
    if test -n "${PIPELINE_VERSIONS_JSON_OVERRIDE}"; then
        if test -z "${sprint}"; then
            most_recent_tag="$(git describe --tags --abbrev=0)"

            # A sprint tag is contains exactly 4 digits in a row, either YYMM or YYMM.X
            # A sprint tag in the docker-builds repository should not contain any letters
            if test "${most_recent_tag##[0-9][0-9][0-9][0-9]}" != "${most_recent_tag}" && test "${most_recent_tag##[A-Za-z]}" = "${most_recent_tag}"; then
                sprint="${most_recent_tag}"
            else
                echo_red "ERROR: Most recent tag ${most_recent_tag} for branch ${CI_COMMIT_BRANCH} does not match form YYMM or YYMM.X" && exit 1
            fi
        fi
        test "${sprint:0:2}" -lt 22 && echo_red "ERROR: The sprint release ${sprint} does not support versions.json override. Use 2201 or newer." && exit 1
    fi

    printf "%s" "${sprint}"
}

# Get the versions.json file path for a specified product name.
# If PIPELINE_VERSIONS_JSON_OVERRIDE is set, use that versions.json instead.
_getVersionsFilePath() {
    test -z "${1}" && echo_red "ERROR: The function _getVersionsFilePath requires a product name input." && exit 1

    product_versions_file="${PIPELINE_VERSIONS_JSON_OVERRIDE:-${CI_PROJECT_DIR}/${1}/versions.json}"

    # Ensure that the file exists before returning the file path.
    ! test -f "${product_versions_file}" && echo_red "ERROR: File ${product_versions_file} not found." && exit 1

    # Ensure that the file contains valid json.
    jq empty "${product_versions_file}"
    test "${?}" -ne 0 && echo_red "ERROR: The JSON supplied in ${product_versions_file} is not valid JSON." && exit 1

    printf "%s" "${product_versions_file}"
}

# Get all versions from versions.json file for a specified product name.
# Only versions with valid jvms for ARCH that have build=true are returned.
_getAllVersionsToBuildForProduct() {
    test -z "${1}" && echo_red "ERROR: The function _getAllVersionsToBuildForProduct requires a product name input." && exit 1

    product_versions_file="$(_getVersionsFilePath "${1}")"
    jq -r --arg regex "$(_getJVMFilterRegex)" \
        '[.versions[] | . as $v | .shims[] | .jvms[] | select(.build==true) | select(.jvm | test($regex)) | $v.version] | unique | .[]' \
        "${product_versions_file}"
}

# Get all versions from versions.json file for a specified product name.
# Only versions with valid jvms for ARCH that have deploy=true are returned.
_getAllVersionsToDeployForProduct() {
    test -z "${1}" && echo_red "ERROR: The function _getAllVersionsToDeployForProduct requires a product name input." && exit 1

    product_versions_file="$(_getVersionsFilePath "${1}")"
    jq -r --arg regex "$(_getJVMFilterRegex)" \
        '[.versions[] | . as $v | .shims[] | .jvms[] | select(.deploy==true) | select(.jvm | test($regex)) | $v.version] | unique | .[]' \
        "${product_versions_file}"
}

# Get the latest version from versions.json file for a specified product name.
_getLatestVersionForProduct() {
    test -z "${1}" && echo_red "ERROR: The function _getLatestVersionForProduct requires a product name input." && exit 1

    product_versions_file="$(_getVersionsFilePath "${1}")"
    jq -r '.latest' "${product_versions_file}"
}

# Get the default shim from versions.json file for a specified product name and version.
_getDefaultShimForProductVersion() {
    test -z "${1}" && echo_red "ERROR: The function _getDefaultShimForProductVersion requires a product name input." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getDefaultShimForProductVersion requires a version input." && exit 1

    product_versions_file="$(_getVersionsFilePath "${1}")"
    jq -r --arg version "${2}" \
        '.versions[]| select(.version == $version) | .preferredShim' \
        "${product_versions_file}"
}

# Get the all shims from versions.json file for a specified product name and version.
# Only shims with valid jvms for ARCH that have build=true are returned.
_getShimsToBuildForProductVersion() {
    test -z "${1}" && echo_red "ERROR: The function _getShimsToBuildForProductVersion requires a product name input." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getShimsToBuildForProductVersion requires a version input." && exit 1

    product_versions_file="$(_getVersionsFilePath "${1}")"
    jq -r --arg regex "$(_getJVMFilterRegex)" \
        --arg version "${2}" \
        '[.versions[] | select(.version == $version) | .shims[] | . as $v | .jvms[] | select(.build==true) | select(.jvm | test($regex)) | $v.shim] | unique | .[]' \
        "${product_versions_file}"
}

# Get the all shims from versions.json file for a specified product name and version.
# Only shims that have deploy=true are returned.
# This is ARCH agnostic as we loop through architectures to deploy in the deploy scripts.
_getShimsToDeployForProductVersion() {
    test -z "${1}" && echo_red "ERROR: The function _getShimsToDeployForProductVersion requires a product name input." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getShimsToDeployForProductVersion requires a version input." && exit 1

    product_versions_file="$(_getVersionsFilePath "${1}")"
    jq -r --arg version "${2}" \
        '[.versions[] | select(.version == $version) | .shims[] | . as $v | .jvms[] | select(.deploy==true) | $v.shim] | unique | .[]' \
        "${product_versions_file}"
}

# Get the all shims from pingjvm/versions.json file for a specified jvm ID.
_getShimsToBuildForJVM() {
    test -z "${1}" && echo_red "ERROR: The function _getShimsToBuildForJVM requires a jvm ID input." && exit 1

    jvm_versions_file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    ! test -f "${jvm_versions_file}" && echo_red "ERROR: File ${jvm_versions_file} not found." && exit 1

    jq -r --arg jvm_id \
        "${1}" '[.versions[] | select(.id == $jvm_id) | .shims[] ] | unique | .[]' \
        "${jvm_versions_file}"
}

# Get the all shims from versions.json file for a specified product name.
_getAllShimsForProduct() {
    test -z "${1}" && echo_red "ERROR: The function _getAllShimsForProduct requires a product name input." && exit 1

    product_versions_file="$(_getVersionsFilePath "${1}")"
    jq -r '[.versions[] | .shims[] | .shim] | unique | .[]' "${product_versions_file}"
}

# Get all the jvm IDs from versions.json file for a specified product name, version, and shim.
# Only jvm IDs valid for ARCH that have build=true are returned.
_getJVMsToBuildForProductVersionShim() {
    test -z "${1}" && echo_red "ERROR: The function _getJVMsToBuildForProductVersionShim requires a product name input." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getJVMsToBuildForProductVersionShim requires a version input." && exit 1
    test -z "${3}" && echo_red "ERROR: The function _getJVMsToBuildForProductVersionShim requires a shim input." && exit 1

    product_versions_file="$(_getVersionsFilePath "${1}")"
    jq -r --arg regex "$(_getJVMFilterRegex)" \
        --arg version "${2}" \
        --arg shim "${3}" \
        '[.versions[] | select(.version == $version) | .shims[] | select(.shim == $shim) | .jvms[] | select(.build==true) | select(.jvm | test($regex)) | .jvm] | unique | .[]' \
        "${product_versions_file}"
}

# Get all the jvm IDs from versions.json file for a specified product name, version, and shim.
# Only jvm IDs valid for ARCH that have deploy=true are returned.
_getJVMsToDeployForProductVersionShim() {
    test -z "${1}" && echo_red "ERROR: The function _getJVMsToDeployForProductVersionShim requires a product name input." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getJVMsToDeployForProductVersionShim requires a version input." && exit 1
    test -z "${3}" && echo_red "ERROR: The function _getJVMsToDeployForProductVersionShim requires a shim input." && exit 1

    product_versions_file="$(_getVersionsFilePath "${1}")"
    jq -r --arg regex "$(_getJVMFilterRegex)" \
        --arg version "${2}" \
        --arg shim "${3}" \
        '[.versions[] | select(.version == $version) | .shims[] | select(.shim == $shim) | .jvms[] | select(.deploy==true) | select(.jvm | test($regex)) | .jvm] | unique | .[]' \
        "${product_versions_file}"
}

# Get the all architectures from pingjvm/versions.json file for a specified jvm ID.
_getAllArchsForJVM() {
    test -z "${1}" && echo_red "ERROR: The function _getAllArchsForJVM requires a jvm ID input." && exit 1

    jvm_versions_file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    ! test -f "${jvm_versions_file}" && echo_red "ERROR: File ${jvm_versions_file} not found." && exit 1

    jq -r --arg jvm_id "${1}" \
        '.versions[] | select(.id == $jvm_id) | .archs | .[]' \
        "${jvm_versions_file}"
}

# Return all jvm IDs from pingjvm/versions.json.
_getAllJVMs() {
    jvm_versions_file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    ! test -f "${jvm_versions_file}" && echo_red "ERROR: File ${jvm_versions_file} not found." && exit 1

    jq -r '.versions[] | .id' "${jvm_versions_file}"
}

# Return all jvm IDs from pingjvm/versions.json that contain an architecture mapping to $ARCH's value.
_getJVMsForArch() {
    jvm_versions_file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    ! test -f "${jvm_versions_file}" && echo_red "ERROR: File ${jvm_versions_file} not found." && exit 1

    jq -r --arg arch "${ARCH}" '.versions[] | select(.archs[] | contains($arch)) | .id' "${jvm_versions_file}"
}

# Take each jvm ID from _getJVMsForArch() and parse them into a jq regex of the form "al11|rl11|az11"
_getJVMFilterRegex() {
    # Compute JVM_FILTER_REGEX once based on JVMS_FOR_ARCH
    if test -z "${JVM_FILTER_REGEX}"; then
        for cur_jvm in $(_getJVMsForArch); do
            JVM_FILTER_REGEX="${JVM_FILTER_REGEX}${JVM_FILTER_REGEX:+|}${cur_jvm}"
        done
        export JVM_FILTER_REGEX
    fi
    printf "%s" "${JVM_FILTER_REGEX:-null}"
}

# Get the default jvm from versions.json files for a specified product name, version, and shim.
_getPreferredJVMForProductVersionShim() {
    test -z "${1}" && echo_red "ERROR: The function _getPreferredJVMForProductVersionShim requires a product name input." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getPreferredJVMForProductVersionShim requires a version input." && exit 1
    test -z "${3}" && echo_red "ERROR: The function _getPreferredJVMForProductVersionShim requires a shim input." && exit 1

    product_versions_file="$(_getVersionsFilePath "${1}")"
    jq -r --arg version "${2}" \
        --arg shim "${3}" \
        '.versions[] | select(.version == $version) | .shims[] | select(.shim == $shim) | .preferredJVM' \
        "${product_versions_file}"
}

# Get the deploy image repositories from versions.json files for a specified product name, version, shim, and jvm ID.
_getTargetRegistriesForProductVersionShimJVM() {
    test -z "${1}" && echo_red "ERROR: The function _getTargetRegistriesForProductVersionShimJVM requires a product name input." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getTargetRegistriesForProductVersionShimJVM requires a version input." && exit 1
    test -z "${3}" && echo_red "ERROR: The function _getTargetRegistriesForProductVersionShimJVM requires a shim input." && exit 1
    test -z "${4}" && echo_red "ERROR: The function _getTargetRegistriesForProductVersionShimJVM requires a jvm ID input." && exit 1

    product_versions_file="$(_getVersionsFilePath "${1}")"
    jq -r --arg version "${2}" \
        --arg shim "${3}" \
        --arg jvm_id "${4}" \
        '.versions[] | select(.version == $version) | .shims[] | select(.shim == $shim) | .jvms[] | select(.jvm == $jvm_id) | .registries[]' \
        "${product_versions_file}"
}

# Get all the jvm IDs from all product versions.json files for a specified shim.
# Only jvm IDs valid for ARCH that have build=true are returned.
_getAllJVMsToBuildForShim() {
    test -z "${1}" && echo_red "ERROR: The function _getAllJVMsToBuildForShim requires a shim input." && exit 1

    find "${CI_PROJECT_DIR}" -type f -not -path "${CI_PROJECT_DIR}/pingjvm/*" -name versions.json > version_files
    while IFS= read -r version_file; do
        new_ids="$(jq -r --arg regex "$(_getJVMFilterRegex)" \
            --arg shim "${1}" \
            '.versions[] | .shims[] | select(.shim == $shim) | .jvms[] | select(.build==true)| select(.jvm | test($regex)) | .jvm' \
            "${version_file}")"
        jvm_ids="${jvm_ids}${jvm_ids:+\n}${new_ids}"
    done < version_files
    rm version_files

    jvm_ids="$(echo -e "${jvm_ids}" | sort | uniq)"
    printf "%s" "${jvm_ids}"
}

# Get the docker build arguments for any dependencies with a specified product name and version.
_getDependenciesForProductVersion() {
    test -z "${1}" && echo_red "ERROR: The function _getDependenciesForProductVersion requires a product name input." && exit 1
    test -z "${2}" && echo_red "ERROR: The function _getDependenciesForProductVersion requires a dependency check version input." && exit 1

    product_versions_file="$(_getVersionsFilePath "${1}")"
    jq -jr --arg version "${2}" \
        '.versions[] | select(.version == $version) | if (.dependencies) then .dependencies[]|.product," ",.version,"\n" else "" end' \
        "${product_versions_file}" |
        awk 'BEGIN{i=0} {print "--build-arg DEPENDENCY_"i"_PRODUCT="$1" --build-arg DEPENDENCY_"i"_VERSION="$2; i++}'
}

# get the the shims (from versions.json)
_getAllShims() {
    find "${CI_PROJECT_DIR}" -type f -not -path "${CI_PROJECT_DIR}/pingjvm/*" -name versions.json > version_files
    while IFS= read -r version_file; do
        new_shims="$(jq -r '[.versions[] | .shims[] | .shim] | unique | .[]' "${version_file}")"
        shims="${shims}${shims:+\n}${new_shims}"
    done < version_files
    rm version_files

    shims="$(echo -e "${shims}" | sort | uniq)"
    printf "%s" "${shims}"
}

# get the long tag
_getLongTag() {
    echo "${1}" | awk '{gsub(/[:\/]/,"_");print}'
}

# get the short tag
_getShortTag() {
    echo "${1}" | awk '{gsub(/:.*/,"");print}'
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

# echos banner contents centering argument passed
banner_head() {
    banner_pad=$(printf '%0.1s' " "{1..80})
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
        pingdirectory | pingdataconsole)
            _product="directory"
            ;;
        pingdirectoryproxy)
            _product="proxy"
            ;;
        pingdatasync)
            _product="sync"
            ;;
        pingauthorize)
            _product="broker"
            ;;
        pingauthorizepap)
            _product="symphonic-pap-packaged"
            _basePath="com/pingidentity/pd/governance"
            ;;
        *) ;;

    esac
    case "${1}" in
        pingdataconsole | pingdatasync | pingdirectory | pingdirectoryproxy | pingauthorize | pingauthorizepap)
            _curl "${_baseURL}/${_basePath}/${_product}/maven-metadata.xml" | xmllint --xpath 'string(/metadata/versioning/latest)' -
            ;;
        pingdelegator)
            _curl "${SNAPSHOT_DELEGATOR_URL}/maven-metadata.xml" | xmllint --xpath 'string(/metadata/versioning/snapshotVersions/snapshotVersion/value)' -
            ;;
        pingcentral)
            # Get lastSuccessfulBuild filename
            product_version_api_json_url="${SNAPSHOT_PINGCENTRAL_URL}/api/json"
            bits_file_name="$(_curl "${product_version_api_json_url}" | jq -r '.artifacts[] | .fileName')"

            #Remove 'ping-central-' and '.zip' from file name to product snapshot version
            snapshot_version="${bits_file_name##ping-central-}"
            snapshot_version="${snapshot_version%%\.zip}"
            echo "${snapshot_version}"
            ;;
        pingfederate)
            _curl "${SNAPSHOT_BLD_FED_URL}/artifact/pf-server/HuronPeak/assembly/base/pom.xml" | sed -e 's/xmlns=".*"//g' | xmllint --xpath 'string(/project/version)' -
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
# Executes the command passed, and fails if return code ne 0
################################################################################
exec_cmd_or_fail() {
    eval "${*}"
    result_code=${?}
    test "${result_code}" -ne 0 && echo_red "The following command resulted in an error: ${*}" && exit "${result_code}"
}

################################################################################
#Executes the command passed, and retries up to 5 times if return code is ne 0
################################################################################
exec_cmd_or_retry() {
    num_retries=5
    while test ${num_retries} -gt 0; do
        num_retries=$((num_retries - 1))
        eval "${*}"
        result_code=${?}
        test ${result_code} -eq 0 && break
        sleep 5
    done
    test "${result_code}" -ne 0 && echo_red "The following command repeatedly resulted in an error: ${*}" && exit "${result_code}"
}

################################################################################
# Kill the passed in process and all of the child processes.
################################################################################
_kill_pid() {

    ppid="${1}"
    cpids=$(pgrep -P "${ppid}" | xargs)
    for cpid in $cpids; do
        _kill_pid "$cpid"
    done
    echo "killing ${ppid}"
    kill "${ppid}" 2> /dev/null
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
    requirePipelineVar DOCKER_ACCESS_TOKEN
    requirePipelineVar DOCKER_HUB_REGISTRY
    mkdir -p "${docker_config_hub_dir}"

    # login to docker.io to create the docker hub config.json
    docker logout https://index.docker.io/v1/
    docker --config "${docker_config_hub_dir}" login --username "${DOCKER_USERNAME}" --password "${DOCKER_ACCESS_TOKEN}"
    test ${?} -ne 0 && echo_red "Error: Failed to login to DockerHub in ci_tools.sh" && exit 1

    ####### SET UP ALL OTHER REGISTRIES #######
    # Ensure that the pipe-line provides the following variables/files
    requirePipelineVar PIPELINE_BUILD_REGISTRY_VENDOR
    requirePipelineVar PIPELINE_BUILD_REGISTRY
    requirePipelineVar PIPELINE_BUILD_REPO
    requirePipelineVar ARTIFACTORY_REGISTRY
    requirePipelineVar ARTIFACTORY_AUTH_TOKEN
    requirePipelineVar FEDRAMP_REGISTRY
    requirePipelineFile DOCKER_CONFIG_JSON

    echo "Using Docker config.json '${DOCKER_CONFIG_JSON}'"
    mkdir -p "${docker_config_default_dir}"
    cp "${DOCKER_CONFIG_JSON}" "${docker_config_default_dir}/config.json"
}

#Define docker config file locations based on different image registry providers
docker_config_hub_dir="$HOME/.docker-hub"
docker_config_default_dir="$HOME/.docker"

if test -n "${PING_IDENTITY_SNAPSHOT}" && test -n "${CI_COMMIT_REF_NAME}"; then
    #we are in building snapshot
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
            # This file is not implemented. Disable shellcheck.
            # shellcheck disable=SC2317
            . "${CI_SCRIPTS_DIR}/azure_tools.lib.sh"
            ;;
    esac

    GIT_REV_SHORT=$(date '+%H%M')
    GIT_REV_LONG=$(date '+%s')
    CI_TAG="$(date '+%Y%m%d')"
elif test -n "${CI_COMMIT_REF_NAME}"; then
    #we are in CI pipeline
    FOUNDATION_REGISTRY="${PIPELINE_BUILD_REGISTRY}/${PIPELINE_BUILD_REPO}"
    # we terminate to DEPS registry with a slash so it can be omitted to revert to implicit
    DEPS_REGISTRY="${PIPELINE_DEPS_REGISTRY}/"

    if test -n "${CUSTOM_IMAGE_PIPELINE}"; then
        # Trick the pipeline to think local. This removes the need to push to ECR for build process,
        # and keeps the images around after serial_build.sh is finished.
        IS_LOCAL_BUILD=true
        export IS_LOCAL_BUILD
        # keep local foundation registry if set
        if test -z "${FOUNDATION_REGISTRY}"; then
            FOUNDATION_REGISTRY="pingidentity"
        fi
    fi

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
            # This file is not implemented. Disable shellcheck.
            # shellcheck disable=SC2317
            . "${CI_SCRIPTS_DIR}/azure_tools.lib.sh"
            ;;
    esac

    #
    # setup the docker trust material.
    #
    requirePipelineVar DOCKER_TRUST_PRIVATE_KEY
    requirePipelineVar DOCKER_TRUST_PRIVATE_KEY_SIGNER
    requirePipelineVar VAULT_ADDR
    requirePipelineVar CI_JOB_JWT

    #Temp file location for docker private keys retrieved from Vault
    keys_temp_file=$(mktemp)

    #Retreive the vault token to authenticate for vault secrets
    VAULT_TOKEN="$(vault write -field=token auth/jwt/login role=pingdevops jwt="${CI_JOB_JWT}")"
    test -z "${VAULT_TOKEN}" && VAULT_TOKEN="$(vault write -field=token auth/jwt/login role=pingdevops-tag jwt="${CI_JOB_JWT}")"
    test -z "${VAULT_TOKEN}" && echo "Error: Vault token was not retrieved" && exit 1
    export VAULT_TOKEN

    #Retreive the vault secret
    vault kv get -field=Signing_Key_Base64 pingdevops/Base64_key > "${keys_temp_file}"
    test $? -ne 0 && echo "Error: Failed to retrieve private docker keys from vault" && exit 1

    #Use private key file with DockerHub
    mkdir -p "${docker_config_hub_dir}/trust/private"
    (cd "${docker_config_hub_dir}/trust/private" && base64 --decode "${keys_temp_file}" | tar -xz)
    docker --config "${docker_config_hub_dir}" trust key load "${docker_config_hub_dir}/trust/private/${DOCKER_TRUST_PRIVATE_KEY}" --name "${DOCKER_TRUST_PRIVATE_KEY_SIGNER}"

    #Use private key file with Artifactory
    mkdir -p "${docker_config_default_dir}/trust/private"
    (cd "${docker_config_default_dir}/trust/private" && base64 --decode "${keys_temp_file}" | tar -xz)
    docker --config "${docker_config_default_dir}" trust key load "${docker_config_default_dir}/trust/private/${DOCKER_TRUST_PRIVATE_KEY}" --name "${DOCKER_TRUST_PRIVATE_KEY_SIGNER}"

    rm -f "${keys_temp_file}"

    #Provide Root CA Certificate for Artifactory Notary Server
    requirePipelineFile ARTIFACTORY_ROOT_CA_FILE
    echo "Using root CA certificate file'${ARTIFACTORY_ROOT_CA_FILE}'"
    cp "${ARTIFACTORY_ROOT_CA_FILE}" "/usr/local/share/ca-certificates/root-ca.crt"
    update-ca-certificates

    requirePipelineVar ARTIFACTORY_NOTARY_SERVER_IP
    echo "Using notary server IP value'${ARTIFACTORY_NOTARY_SERVER_IP}'"
    echo "${ARTIFACTORY_NOTARY_SERVER_IP} notaryserver" | sudo tee -a /etc/hosts > /dev/null

    GIT_REV_SHORT=$(git rev-parse --short=4 "$CI_COMMIT_SHA")
    GIT_REV_MED=$(git rev-parse --short "$CI_COMMIT_SHA")
    GIT_REV_LONG=$(git rev-parse "$CI_COMMIT_SHA")
    CI_TAG="${CI_COMMIT_REF_NAME}-${CI_COMMIT_SHORT_SHA}"
else
    #we are on local
    IS_LOCAL_BUILD=true
    export IS_LOCAL_BUILD
    # keep local foundation registry if set
    if test -z "${FOUNDATION_REGISTRY}"; then
        FOUNDATION_REGISTRY="pingidentity"
    fi
    DEPS_REGISTRY="${DEPS_REGISTRY_OVERRIDE}"
    gitBranch=$(git rev-parse --abbrev-ref HEAD)
    GIT_REV_SHORT=$(git rev-parse --short=4 HEAD)
    GIT_REV_MED=$(git rev-parse --short HEAD)
    GIT_REV_LONG=$(git rev-parse HEAD)
    CI_TAG="${gitBranch}-${GIT_REV_SHORT}"
fi
ARCH="$(uname -m)"
export ARCH
export FOUNDATION_REGISTRY
export DEPS_REGISTRY
export GIT_REV_SHORT
export GIT_REV_MED
export GIT_REV_LONG
export gitBranch
export CI_TAG

#
# Stop execution of ci_script if ARCH (i.e. aarch64) is not included in BUILD_ARCH
#
if test -n "${BUILD_ARCH}"; then
    grep "\b${ARCH}\b" <<< "${BUILD_ARCH}" > /dev/null
    if test $? -eq 1; then
        echo "This architecture (${ARCH}) is not in list of BUILD_ARCHs (${BUILD_ARCH})"
        echo "Exiting with a 0"
        exit 0
    fi
    echo "This architecture (${ARCH}) found in BUILD_ARCHs (${BUILD_ARCH})"
    echo "Continuing"
fi
