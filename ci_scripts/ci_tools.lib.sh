#!/usr/bin/env bash
test -n "${VERBOSE}" && set -x

HISTFILE=~/.bash_history
set -o history
export HISTTIMEFORMAT='%T'

# get all version for a product to build
function _getAllVersionsToBuildForProduct ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]|[. as $v | .distributions[]|select(.build==true)|$v.version]|unique|.[]' "${_file}"
}

# get all version for a product to build
function _getAllVersionsToDeployForProduct ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]|[. as $v | .distributions[]|select(.deploy==true)|$v.version]|unique|.[]' "${_file}"
}

# get the latest version of a product to build
function _getLatestVersionForProduct () 
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r 'if (.latest) then .latest else "" end' "${_file}"
}

# get the default shim for a product version
function _getDefaultShimForProductVersion () 
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '.|.versions[]| select(.version == "'${2}'") | .preferredShim' "${_file}"
}

# get all the shims for a product version
function _getShimsToBuildForProductVersion ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '[.|.versions[]| select(.version == "'${2}'")|.distributions[]|select(.build==true)|.shim]|unique|.[]' "${_file}"
}

# get all the shims for a product version
function _getShimsToDeployForProductVersion ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '[.|.versions[]| select(.version == "'${2}'")|.distributions[]|select(.deploy==true)|.shim]|unique|.[]' "${_file}"
}

# get all the shims for a product
function _getAllShimsForProduct ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '[.|.versions[]|.distributions[]|.shim]|unique|.[]' "${_file}"
}

function _getJDKForProductVersionShim ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '.|.versions[]|select(.version=="'${2}'").distributions[]|select(.shim=="'${3}'")|.jdk' "${_file}"
}

function _getDependenciesForProductVersion ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -jr '.versions[]|select( .version == "'${2}'" )|if (.dependencies) then .dependencies[]|.product," ",.version,"\n" else "" end' "${_file}" | awk 'BEGIN{i=0} {print "--build-arg DEPENDENCY_"i"_PRODUCT="$1" --build-arg DEPENDENCY_"i"_VERSION="$2; i++}'
}

function _getLongTag () 
{
    echo "${1}" | awk '{gsub(/:/,"_");print}'
}

function _getShortTag () 
{
    echo "${1}"| awk '{gsub(/:.*/,"");print}'
}

function _getAllShims ()
{    
    find "${CI_PROJECT_DIR}" -type f -not -path "${PWD}/pingjvm/*" -name versions.json -exec jq -r '[.|.versions[]|.distributions[]|.shim]|unique|.[]' {} + | sort | uniq
}

# returns the license version for a product full version
function _getLicenseVersion ()
{
    echo ${1}| cut -d. -f1,2
}

banner_pad=$( printf '%0.1s' " "{1..80})
function banner_bar ()
{
    printf '%0.1s' "#"{1..80}
    printf "\n"
}

function banner_head ()
{
    # line is divided like so # <- a -> b <- c ->#
    # b is the string to display centered
    # a and c are whitespace padding to center the string
    _b="${*}"
    if test ${#_b} -gt 78 ;
    then
        _a=0
        _c=0
    else
        _a=$(( ( 78 - ${#_b} ) / 2 ))
        _c=$(( 78 - ${_a} - ${#_b} ))
    fi
    printf "#"
    printf '%*.*s' 0 ${_a} "${banner_pad}"
    printf "${_b}"
    printf '%*.*s' 0 ${_c} "${banner_pad}"
    printf "#\n"
}

function banner ()
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

append_status ()
{
    _output="${1}"
    shift
    if test "${1}" = "PASS" ;
    then
        _prefix=${FONT_GREEN}${CHAR_CHECKMARK}
    else
        _prefix=${FONT_RED}${CHAR_CROSSMARK}
    fi
    shift
    _pattern="${1}"
    shift
    printf ${_prefix}${_pattern}${FONT_NORMAL}'\n' "${@}" >> ${_output}

}

if test -n "${CI_COMMIT_REF_NAME}" ; then
  #we are in CI pipeline
  export FOUNDATION_REGISTRY="gcr.io/ping-identity"
  # shellcheck disable=SC2155
  export gitRevShort=$( git rev-parse --short=4 "$CI_COMMIT_SHA" )
  # shellcheck disable=SC2155
  export gitRevLong=$( git rev-parse "$CI_COMMIT_SHA" )
  export ciTag="${CI_COMMIT_REF_NAME}-${CI_COMMIT_SHORT_SHA}"
else
  #we are on local
  # shellcheck disable=SC2034
  isLocalBuild=true
  export FOUNDATION_REGISTRY="pingidentity"
  # shellcheck disable=SC2155
  export gitBranch=$(git rev-parse --abbrev-ref HEAD)
  # shellcheck disable=SC2155
  export gitRevShort=$( git rev-parse --short=4 HEAD)
  # shellcheck disable=SC2155
  export gitRevLong=$( git rev-parse HEAD) 
  export ciTag="${gitBranch}-${gitRevShort}"
fi