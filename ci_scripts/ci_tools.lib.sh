#!/usr/bin/env bash
set -x
HISTFILE=~/.bash_history
set -o history
export HISTTIMEFORMAT='%T'

if test -n "${CI_COMMIT_REF_NAME}" ; then
  #we are in CI pipeline
  FOUNDATION_REGISTRY="gcr.io/ping-identity"
  gitRevShort=$( git rev-parse --short=4 "$CI_COMMIT_SHA" )
  gitRevLong=$( git rev-parse "$CI_COMMIT_SHA" )
  ciTag="${CI_COMMIT_REF_NAME}-${CI_COMMIT_SHORT_SHA}"
else
  #we are on local
  FOUNDATION_REGISTRY="pingidentity"
  gitBranch=$(git rev-parse --abbrev-ref HEAD)
  gitRevShort=$( git rev-parse --short=4 HEAD)
  gitRevLong=$( git rev-parse HEAD) 
  ciTag="${gitBranch}-${gitRevShort}"
fi