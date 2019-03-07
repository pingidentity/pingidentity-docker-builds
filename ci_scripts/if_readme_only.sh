#!/usr/bin/env sh

set -e 

#for local, uncomment:
# CHANGED_FILES=$(git diff --name-only master HEAD^)
# echo "edited files: " $CHANGED_FILES

CHANGED_FILES=$(git diff --name-only "$CI_COMMIT_SHA"  "$CI_COMMIT_BEFORE_SHA")
echo "CHANGED_FILES: " $CHANGED_FILES
ONLY_READMES=True
MD="\.md"

for CHANGED_FILE in $CHANGED_FILES; do
  echo $CHANGED_FILE
  echo "TESTING - ${CHANGED_FILE#*$MD} != ${CHANGED_FILE}"
  if test "${CHANGED_FILE#*$MD}" = "${CHANGED_FILE}" ; then
    echo "found non-readme"
    ONLY_READMES=False
    break
  fi
done

if test $ONLY_READMES = True ; then
  echo "Only .md files found, exiting."
  exit 1
else
  echo "Non-.md files found, continuing with build."
fi




# #!/usr/bin/env sh

# set -e

# #for local, uncomment:
# #CHANGED_FILES=$(git diff --name-only master HEAD^)
# #echo "edited files: " $CHANGED_FILES

# # CHANGED_FILES=$(git diff --name-only "$CI_COMMIT_SHA"  "$CI_COMMIT_BEFORE_SHA")
# # echo "CHANGED_FILES: " $CHANGED_FILES
# ONLY_READMES=True
# MD=".md"

# for CHANGED_FILE in $CHANGED_FILES; do
#   echo $CHANGED_FILE

#   echo "TESTING - ${CHANGED_FILE#*$MD} != ${CHANGED_FILE}"

#   test "${CHANGED_FILE#*$MD}" != "${CHANGED_FILE}" && echo "$MD found in $CHANGED_FILE"

#   if test "${CHANGED_FILE#*$MD}" = "${CHANGED_FILE}" ; then
#     echo "found non-readme"
#     ONLY_READMES=False
#     break
#   fi
# done

# if test $ONLY_READMES = True ; then
#   echo "Only .md files found, exiting."
#   exit 1
# else
#   echo "Non-.md files found, continuing with build."
# fi