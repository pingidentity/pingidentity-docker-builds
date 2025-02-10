#!/usr/bin/env bash
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - CI scripts
#
# This script will cleanup a docker environment
#
test "${VERBOSE}" = "true" && set -x

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

banner "Cleaning containers and images ( CI_TAG = ${CI_TAG} )"

# stop containers
_containers=$(docker container ls -q | sort | uniq)
# Word-split is expected behavior for $_containers. Disable shellcheck.
# shellcheck disable=SC2086
test -n "${_containers}" && docker container stop ${_containers}

_containers=$(docker container ls -aq | sort | uniq)
# Word-split is expected behavior for $_containers. Disable shellcheck.
# shellcheck disable=SC2086
test -n "${_containers}" && docker container rm -f ${_containers}

imagesToClean=$(docker image ls -qf "reference=*/*/*${CI_TAG}" | sort | uniq)
# Word-split is expected behavior for $imagesToClean. Disable shellcheck.
# shellcheck disable=SC2086
test -n "${imagesToClean}" && docker image rm -f ${imagesToClean}
imagesToClean=$(docker image ls -qf "dangling=true")
# Word-split is expected behavior for $imagesToClean. Disable shellcheck.
# shellcheck disable=SC2086
test -n "${imagesToClean}" && docker image rm -f ${imagesToClean}

# clean all images if full clean is requested
if test "${1}" = "full"; then
    docker system prune -af
fi

exit 0
