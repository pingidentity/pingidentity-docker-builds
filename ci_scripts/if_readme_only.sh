#!/usr/bin/env sh
set -x

#for local, uncomment:
# CHANGED_FILES=$(git diff --name-only master HEAD)
# echo "edited files: " $CHANGED_FILES

# for gitlab: 
echo "$CI_COMMIT_BEFORE_SHA"
CHANGED_FILES=$(git diff --name-only "$CI_COMMIT_SHA"  "$CI_COMMIT_BEFORE_SHA")
echo "CHANGED_FILES: " "$CHANGED_FILES"

ONLY_READMES=True
MD="\.md"

check_if_mds()
{
  for CHANGED_FILE in $CHANGED_FILES; do
    echo "$CHANGED_FILE"
    echo "TESTING - ${CHANGED_FILE#*$MD} != ${CHANGED_FILE}"
    if test "${CHANGED_FILE#*$MD}" = "${CHANGED_FILE}" ; then
      echo "found non-readme"
      ONLY_READMES=False
      break
    fi
  done
}


if [ "$CI_COMMIT_BEFORE_SHA" = "0000000000000000000000000000000000000000" ]
then
   echo "no previous commit, continue build"
   exit 0
else 
  echo "found"
  check_if_mds
fi


if test $ONLY_READMES = True ; then
  echo "Only .md files found, exiting."
  exit 1
else
  echo "Non-.md files found, continuing with build."
fi