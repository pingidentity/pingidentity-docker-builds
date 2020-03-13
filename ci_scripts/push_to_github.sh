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

rm -rf ~/tmp/build
mkdir -p ~/tmp/build && cd ~/tmp/build || exit 9

git clone https://${GITLAB_USER}:${GITLAB_TOKEN}@gitlab.corp.pingidentity.com/devops-program/docker-builds
cd docker-builds || exit 97
git config user.email "devops_program@pingidentity.com"
git config user.name "devops_program"

git remote add gh_location https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/pingidentity/pingidentity-docker-builds.git

if test -n "$CI_COMMIT_TAG"; then
  git push gh_location "$CI_COMMIT_TAG"
fi

git push gh_location master
