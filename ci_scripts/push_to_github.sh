#!/usr/bin/env bash
if test ! -z "${CI_COMMIT_REF_NAME}" ; then
  . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
  # shellcheck source=~/projects/devops/pingidentity-docker-builds/ci_scripts/ci_tools.lib.sh
  . ${HOME}/projects/devops/pingidentity-docker-builds/ci_scripts/ci_tools.lib.sh
fi

rm -rf /tmp/build
mkdir -p /tmp/build && cd /tmp/build || exit 9

git clone https://${GITLAB_USER}:${GITLAB_TOKEN}@gitlab.corp.pingidentity.com/devops-program/docker-builds
cd docker-builds
git config user.email "devops_program@pingidentity.com"
git config user.name "devops_program"

git remote add gh_location https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/pingidentity/pingidentity-docker-builds.git

if test -n "$CI_COMMIT_TAG"; then
  git push gh_location "$CI_COMMIT_TAG"
fi

git push gh_location master

history | tail -100