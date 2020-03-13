#!/usr/bin/env bash
test -n "${VERBOSE}" && set -x

if test -z "${CI_COMMIT_REF_NAME}" ;then
    # shellcheck disable=SC2046
    CI_PROJECT_DIR="$( cd $(dirname "${0}")/.. || exit 97 ; pwd )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts";
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

"${CI_SCRIPTS_DIR}/cleanup_docker.sh" full
"${CI_SCRIPTS_DIR}/build_downloader.sh" 
"${CI_SCRIPTS_DIR}/build_foundation.sh" 

for p in apache-jmeter ldap-sdk-tools pingaccess pingcentral pingdataconsole pingdatagovernance pingdatagovernancepap pingdatasync pingdirectory pingfederate pingtoolkit ;
do
    "${CI_SCRIPTS_DIR}/build_product.sh" -p ${p} --no-cache --no-build-kit
    test ${?} -ne 0 && break
done