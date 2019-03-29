#!/usr/bin/env  
rm -rf /tmp/build
mkdir -p /tmp/build && cd /tmp/build || exit 9

git clone https://${GITLAB_USER}:${GITLAB_TOKEN}@gitlab.corp.pingidentity.com/devops-program/docker-builds
cd docker-builds
git config user.email "devops_program@pingidentity.com"
git config user.name "devops_program"

git remote add gh_location https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/pingidentity/docker-builds.git

git push gh_location master
