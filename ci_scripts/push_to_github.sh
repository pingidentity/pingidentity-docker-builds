#!/usr/bin/env  
set -x

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