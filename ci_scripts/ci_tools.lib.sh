#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# Utilities used across all CI scripts
#
test -n "${VERBOSE}" && set -x

HISTFILE=~/.bash_history
set -o history
HISTTIMEFORMAT='%T'
export HISTTIMEFORMAT

# get all versions (from versions.json) for a product to build
_getAllVersionsToBuildForProduct ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]|[. as $v |.shims[]|.jvms[]|select(.build==true)|$v.version]|unique|.[]' "${_file}"
}

# get all versions (from versions.json) for a product to deploy
_getAllVersionsToDeployForProduct ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]|[. as $v |.shims[]|.jvms[]|select(.deploy==true)|$v.version]|unique|.[]' "${_file}"
}

# get the latest (from versions.json) version of a product to build
_getLatestVersionForProduct ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r 'if (.latest) then .latest else "" end' "${_file}"
}

# get the default shim (from versions.json) for a product version
_getDefaultShimForProductVersion ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '.|.versions[]| select(.version == "'${2}'") | .preferredShim' "${_file}"
}

# get all the shims (from versions.json) for a product version
_getShimsToBuildForProductVersion ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '[.|.versions[]| select(.version == "'${2}'")|.shims[]|. as $v|.jvms[]|select(.build==true)|$v.shim]|unique|.[]' "${_file}"
}

# get all the shims (from versions.json) for a product version
_getShimsToDeployForProductVersion ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '[.|.versions[]| select(.version == "'${2}'")|.shims[]|. as $v|.jvms[]|select(.deploy==true)|$v.shim]|unique|.[]' "${_file}"
}

# get all the shims (from versions.json) for a product
_getAllShimsForProduct ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '[.|.versions[]|.shims[]|.shim]|unique|.[]' "${_file}"
}

# get all the jvms (from versions.json) for a product to build
_getJVMsToBuildForProductVersionShim ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '.|.versions[]|select(.version=="'${2}'").shims[]|select(.shim=="'${3}'")|.jvms[]|select(.build==true)|.jvm' "${_file}"
}

# get all the jvms (from versions.json) for a product to deploy
_getJVMsToDeployForProductVersionShim ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '.|.versions[]|select(.version=="'${2}'").shims[]|select(.shim=="'${3}'")|.jvms[]|select(.deploy==true)|.jvm' "${_file}"
}

# get the preferred (from versions.json) for a product, version and shim
_getPreferredJVMForProductVersionShim ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '.|.versions[]|select(.version=="'${2}'").shims[]|select(.shim=="'${3}'")|.preferredJVM' "${_file}"
}

# get the jvm versions (from versions.json) for an ID
_getJVMVersionForID ()
{
    _file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    jq -r '.|.versions[]|select(.id=="'${1}'")|.version' "${_file}"
}

# get the jvm IDs (from versions.json) for a shim
_getAllJVMIDsForShim ()
{
    _file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    jq -r '[.versions[]|select(.shims[]|contains("'${1}'"))|.id]|unique|.[]' ${_file}
}

# get the jvms (from versions.json) to build for a shim
_getAllJVMsToBuildForShim ()
{
    # _file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    # jq -r '[.versions[]|select(.shims[]|contains("'${1}'"))|.id]|unique|.[]' ${_file}
    find "${CI_PROJECT_DIR}" -type f -not -path "${CI_PROJECT_DIR}/pingjvm/*" -name versions.json -exec jq -r '.|.versions[]|.shims[]|select(.shim=="'${1}'")|.jvms[]|select(.build==true)|.jvm' {} + 2>/dev/null| sort | uniq
}

# get the jvms (from versions.json) to build
_getAllJVMsToBuild ()
{
    find "${CI_PROJECT_DIR}" -type f -not -path "${CI_PROJECT_DIR}/pingjvm/*" -name versions.json -exec jq -r '.|.versions[]|.shims[]|.jvms[]|select(.build==true)|.jvm' {} + 2>/dev/null| sort | uniq
}

# get the jvm imags (from versions.json) for a shim ID
_getJVMImageForShimID ()
{
    _file="${CI_PROJECT_DIR}/pingjvm/versions.json"
    jq -r '[.versions[]|select(.shims[]|contains("'${1}'"))| select(.id=="'${2}'")|.from]|unique|.[]' ${_file}
}

# get the dependencies (from versions.json) for product version
_getDependenciesForProductVersion ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -jr '.versions[]|select( .version == "'${2}'" )|if (.dependencies) then .dependencies[]|.product," ",.version,"\n" else "" end' "${_file}" | awk 'BEGIN{i=0} {print "--build-arg DEPENDENCY_"i"_PRODUCT="$1" --build-arg DEPENDENCY_"i"_VERSION="$2; i++}'
}

# get the long tag
_getLongTag ()
{
    echo "${1}" | awk '{gsub(/:/,"_");print}'
}

# get the short tag
_getShortTag ()
{
    echo "${1}"| awk '{gsub(/:.*/,"");print}'
}

# get the the shims (from versions.json)
_getAllShims ()
{
    find "${CI_PROJECT_DIR}" -type f -not -path "${CI_PROJECT_DIR}/pingjvm/*" -name versions.json -exec jq -r '[.|.versions[]|.shims[]|.shim]|unique|.[]' {} + 2>/dev/null | sort | uniq
}

# returns the license version from the full product version
#
# Example: 8.1.0.1 --> 8.1
_getLicenseVersion ()
{
    echo ${1}| cut -d. -f1,2
}

# echos banner bar of 80 hashes '#'
banner_bar ()
{
    printf '%0.1s' "#"{1..80}
    printf "\n"
}

banner_pad=$( printf '%0.1s' " "{1..80})
# echos banner contents centering argument passed
banner_head ()
{
    # line is divided like so # <- a -> b <- c ->#
    # b is the string to display centered
    # a and c are whitespace padding to center the string
    _b="${*}"
    if test ${#_b} -gt 78
    then
        _a=0
        _c=0
    else
        _a=$(( ( 78 - ${#_b} ) / 2 ))
        _c=$(( 78 - ${_a} - ${#_b} ))
    fi
    printf "#"
    printf '%*.*s' 0 ${_a} "${banner_pad}"
    # shellcheck disable=SC2059
    printf "${_b}"
    printf '%*.*s' 0 ${_c} "${banner_pad}"
    printf "#\n"
}

# echos full banner with contents
banner ()
{
    banner_bar
    banner_head "${*}"
    banner_bar
}

FONT_RED='\033[0;31m'
FONT_GREEN='\033[0;32m'
FONT_NORMAL='\033[0m'
CHAR_CHECKMARK='\xE2\x9C\x94'
CHAR_CROSSMARK='\xE2\x9D\x8C'

################################################################################
# Echo message in red color
################################################################################
echo_red()
{
    echo -e "${FONT_RED}$*${FONT_NORMAL}"
}

################################################################################
# Echo message in green color
################################################################################
echo_green()
{
    echo -e "${FONT_GREEN}$*${FONT_NORMAL}"
}

################################################################################
# append to output following a colorized pattern
################################################################################
append_status ()
{
    _output="${1}"
    shift
    if test "${1}" = "PASS"
    then
        _prefix="${FONT_GREEN}${CHAR_CHECKMARK} "
    else
        _prefix="${FONT_RED}${CHAR_CROSSMARK}"
    fi
    shift
    _pattern="${1}"
    shift
    printf "${_prefix}${_pattern}${FONT_NORMAL}\n" "${@}" >> ${_output}

}

################################################################################
# Convenience function for curl
################################################################################
_curl ()
{
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
_getLatestSnapshotVersionForProduct ()
{
    _baseURL="http://nexus-qa.austin-eng.ping-eng.com:8081/nexus/service/local/repositories/snapshots/content"
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
        pingdatagovernance)
            _product="broker"
            ;;
        pingdatagovernancepap)
            _product="symphonic-pap-packaged"
            _basePath="com/pingidentity/pd/governance"
            ;;
        *)
            ;;
    esac
    case "${1}" in
        pingdatagovernance|pingdatagovernancepap|pingdatasync|pingdirectory|pingdirectoryproxy)
            _curl "${_baseURL}/${_basePath}/${_product}/maven-metadata.xml" | xmllint --xpath 'string(/metadata/versioning/latest)' -
            ;;
        pingcentral)
            _curl "https://art01.corp.pingidentity.com/artifactory/repo/com/pingidentity/pass/pass-common/maven-metadata.xml" | sed -e 's/xmlns=".*"//g' | xmllint --xpath 'string(/metadata/versioning/latest)' -
            # echo "1.4.0-SNAPSHOT"
            ;;
        pingfederate)
            _curl "https://bld-fed01.corp.pingidentity.com/job/PingFederate_Mainline/lastSuccessfulBuild/artifact/pf-server/HuronPeak/assembly/pom.xml" | sed -e 's/xmlns=".*"//g' | xmllint --xpath 'string(/project/version)' -
            ;;
        pingaccess)
            _curl "https://art01.corp.pingidentity.com/artifactory/repo/com/pingidentity/products/pingaccess/maven-metadata.xml" | sed -e 's/xmlns=".*"//g' | xmllint --xpath 'string(/metadata/versioning/latest)' -
            ;;
    esac
    return ${?}
}

if test -n "${PING_IDENTITY_SNAPSHOT}"
then
    #we are in building snapshot
    FOUNDATION_REGISTRY="art01.corp.pingidentity.com:5200"
    # shellcheck disable=SC2155
    gitRevShort=$( date '+%H%M')
    # shellcheck disable=SC2155
    gitRevLong=$( date '+%s' )
    # shellcheck disable=SC2155
    ciTag="$( date '+%Y%m%d' )"
elif test -n "${CI_COMMIT_REF_NAME}"
then
    #we are in CI pipeline
    FOUNDATION_REGISTRY="gcr.io/ping-gte"
    # FOUNDATION_REGISTRY="574076504146.dkr.ecr.us-west-2.amazonaws.com"
    # shellcheck disable=SC2155
    gitRevShort=$( git rev-parse --short=4 "$CI_COMMIT_SHA" )
    # shellcheck disable=SC2155
    gitRevLong=$( git rev-parse "$CI_COMMIT_SHA" )
    ciTag="${CI_COMMIT_REF_NAME}-${CI_COMMIT_SHORT_SHA}"
else
    #we are on local
    # shellcheck disable=SC2034
    isLocalBuild=true
    FOUNDATION_REGISTRY="pingidentity"
    # shellcheck disable=SC2155
    gitBranch=$(git rev-parse --abbrev-ref HEAD)
    # shellcheck disable=SC2155
    gitRevShort=$( git rev-parse --short=4 HEAD)
    # shellcheck disable=SC2155
    gitRevLong=$( git rev-parse HEAD)
    ciTag="${gitBranch}-${gitRevShort}"
fi
export FOUNDATION_REGISTRY
export gitRevShort
export gitRevLong
export gitBranch
export ciTag