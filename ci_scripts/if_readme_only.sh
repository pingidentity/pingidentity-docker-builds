#!/usr/bin/env sh

set -e

#for local, uncomment:
# CHANGED_FILES=$(git diff --name-only master HEAD^)
# echo "edited files: " $(git diff --name-only master HEAD^)

CHANGED_FILES=$(git diff --name-only "$CI_COMMIT_SHA"  "$CI_COMMIT_BEFORE_SHA")
echo "CHANGED_FILES: " $(git diff --name-only $CI_COMMIT_SHA  $CI_COMMIT_BEFORE_SHA)
ONLY_READMES=True
MD=".md"

for CHANGED_FILE in $CHANGED_FILES; do
  echo $CHANGED_FILE
  if test $(expr $CHANGED_FILE : '.md') ; then
    echo "changed"
    ONLY_READMES=False
    break
  fi
done

if [ $ONLY_READMES = True ]; then
  echo "Only .md files found, exiting."
  travis_terminate 0
  exit 1
else
  echo "Non-.md files found, continuing with build."
fi