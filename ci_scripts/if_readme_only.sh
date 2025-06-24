#!/usr/bin/env bash
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - CI scripts
#
# Check if the changes only includes markdown (.md) files
#
test "${VERBOSE}" = "true" && set -x

# for local, uncomment:
# CHANGED_FILES=$( git diff --name-only master HEAD )
# echo "edited files: " $CHANGED_FILES

# for gitlab:
# set all file ownership to the gitlab-runner user
sudo chown -R gitlab-runner:gitlab-runner .
CHANGED_FILES=$(git diff --name-only "${CI_COMMIT_BEFORE_SHA}" "${CI_COMMIT_SHA}")
echo "CHANGED_FILES:  ${CHANGED_FILES}"

if test "${CI_COMMIT_BEFORE_SHA}" = "0000000000000000000000000000000000000000"; then
    echo "no previous commit."
fi

echo "All checks cleared. Proceeding with build..."
exit 0
