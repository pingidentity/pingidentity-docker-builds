#!/usr/bin/env bash
test -n "${VERBOSE}" && set -x

HISTFILE=~/.bash_history
set -o history
export HISTTIMEFORMAT='%T'

# get all version for a product to build
function _getVersionsFor ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]|.version' "${_file}"
    # test -f "${CI_PROJECT_DIR}/${1}/versions" && awk '$0 !~ /^ *#/{print $1}' "${CI_PROJECT_DIR}/${1}/versions"
}

# get the latest version of a product to build
function _getLatestVersionFor () 
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    test -f "${_file}" && jq -r '.|.versions[]| select(.latest == true) |.version' "${_file}"
    # test -f "${CI_PROJECT_DIR}/${1}/versions" && awk '$0 !~ /^ *#/{print $1;exit}' "${CI_PROJECT_DIR}/${1}/versions"
}

# get the default shim for a product version
function _getDefaultShimFor () 
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '.|.versions[]| select(.version == "'${2}'")|.distributions[] | select(.preferred == true ) | .shim' "${_file}"
    # test -f "${CI_PROJECT_DIR}/${1}/versions" && awk '$1~/^'${2}'$/{print $2}' "${CI_PROJECT_DIR}/${1}/versions"
}

# get all the shims for a product version
function _getShimsFor ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '[.|.versions[]| select(.version == "'${2}'")|.distributions[]|.shim]|unique|.[]' "${_file}"
    # test -f "${CI_PROJECT_DIR}/${1}/versions" && awk '$1~/^'${2}'$/{$1=""; print}' "${CI_PROJECT_DIR}/${1}/versions"
}

# get all the shims for a product
function _getAllShimsFor ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '[.|.versions[]|.distributions[]|.shim]|unique|.[]' "${_file}"
    # test -f "${CI_PROJECT_DIR}/${1}/versions" && awk '$0 !~ /^ *#/{for(i=2;i<=NF;i++){shims[$i]=1;}} END{for(shim in shims){print shim;}}' "${CI_PROJECT_DIR}/${1}/versions"
}

function _getJDKForProductVersionShim ()
{
    _file="${CI_PROJECT_DIR}/${1}/versions.json"
    jq -r '.|.versions[]|select(.version=="'${2}'").distributions[]|select(.shim=="'${3}'")|.jdk' "${_file}"
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
    find "${CI_PROJECT_DIR}" -type f -not -path "./pingjvm/*" -name versions.json -exec jq -r '[.|.versions[]|.distributions[]|.shim]|unique|.[]' {} + | sort | uniq
    # find "${CI_PROJECT_DIR}" -type f -name versions -exec awk '$0!~/^ *#/ {for(i=2;i<=NF;i++){shims[$i]=1;}} END{for(shim in shims){print shim;}}' {} +
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



if test -n "${CI_COMMIT_REF_NAME}" ; then
  #we are in CI pipeline
  export FOUNDATION_REGISTRY="gcr.io/ping-identity"
  export gitRevShort=$( git rev-parse --short=4 "$CI_COMMIT_SHA" )
  export gitRevLong=$( git rev-parse "$CI_COMMIT_SHA" )
  export ciTag="${CI_COMMIT_REF_NAME}-${CI_COMMIT_SHORT_SHA}"
else
  #we are on local
  isLocalBuild=true
  export FOUNDATION_REGISTRY="pingidentity"
  export gitBranch=$(git rev-parse --abbrev-ref HEAD)
  export gitRevShort=$( git rev-parse --short=4 HEAD)
  export gitRevLong=$( git rev-parse HEAD) 
  export ciTag="${gitBranch}-${gitRevShort}"
fi