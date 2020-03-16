#!/usr/bin/env bash
test -n "${VERBOSE}" && set -x
if test -z "${CI_COMMIT_REF_NAME}" ;then
    # shellcheck disable=SC2046 
    CI_PROJECT_DIR="$( cd $( dirname "${0}" )/.. || exit 97 ; pwd )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97

fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

_unmerged=$( grep -Rl '<<<<<<<' ${CI_PROJECT_DIR} | grep -v ${0} | wc -l )

test ${_unmerged} -eq 0 && exit 0
exit 1