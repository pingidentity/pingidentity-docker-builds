#!/usr/bin/env sh
usage ()
{
    echo "${*}"
    cat <<END_USAGE
Usage: ${0} {file}
END_USAGE
    exit 99
}
test -z "${1}" && usage "Missing shell script file parameter"

# This script changes to the location of the script
# because some of the source instructions are relative
# to the location of the script
WD="$( cd "$( dirname "${0}" )"/.. || exit 97 ; pwd )"
cd "$( dirname "${1}" )" || exit 98
"${WD}"/shellcheck -x "$( basename "${1}" )"