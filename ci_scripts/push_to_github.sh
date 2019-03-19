#!/usr/bin/env sh

cd ~/tmp
#get current commit
if [ -d "${docker-builds}" ]; then
  git clone https://${GITLAB_USER}:${GITLAB_TOKEN}@gitlab.corp.pingidentity.com/devops-program/docker-builds
  cd docker-builds
else 
  rm -rf docker-builds
  git clone https://${GITLAB_USER}:${GITLAB_TOKEN}@gitlab.corp.pingidentity.com/devops-program/docker-builds
  cd docker-builds
fi

git remote add gh_location https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/pingidentity/docker-builds.git

#don't put CI stuff on public. 
git checkout -b CI 

git rm -r ci_scripts/ .gitlab-ci.yml

git push gh_location CI

cd ..
rm -rf docker-builds
