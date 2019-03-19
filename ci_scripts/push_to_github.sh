#!/usr/bin/env sh

cd ~/tmp
#get current commit
if [ ! -d "${docker-builds}" ]; then
  git clone https://${GITLAB_USER}:${GITLAB_TOKEN}@gitlab.corp.pingidentity.com/devops-program/docker-builds
  cd docker-builds
  git config user.email "devops_program@pingidentity.com"
  git config user.name "devops_program"
else 
  rm -rf docker-builds
  git clone https://${GITLAB_USER}:${GITLAB_TOKEN}@gitlab.corp.pingidentity.com/devops-program/docker-builds
  cd docker-builds
  git config user.email "devops_program@pingidentity.com"
  git config user.name "devops_program"
fi

git remote add gh_location https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/pingidentity/docker-builds.git

#don't put CI stuff on public. 
git checkout CI
git pull origin CI

git rm -r ci_scripts/ .gitlab-ci.yml

git commit --amend --no-edit

git push gh_location CI

cd ..
rm -rf docker-builds