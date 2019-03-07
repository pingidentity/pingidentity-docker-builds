#!/usr/bin/env sh

set -e

CHANGED_FILES=$(git diff --name-only "$CI_COMMIT_SHA"  "$CI_COMMIT_BEFORE_SHA")
echo "edited files: " $(git diff --name-only $CI_COMMIT_SHA  $CI_COMMIT_BEFORE_SHA)

git remote -v
ONLY_READMES=True
MD=".md"

for CHANGED_FILE in $CHANGED_FILES; do
  if ! [[ $CHANGED_FILE =~ $MD ]]; then
    ONLY_READMES=False
    break
  fi
done

if [[ $ONLY_READMES == True ]]; then
  echo "Only .md files found, exiting."
  travis_terminate 0
  exit 1
else
  echo "Non-.md files found, continuing with build."
fi