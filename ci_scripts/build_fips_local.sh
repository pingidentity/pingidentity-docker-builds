#!/usr/bin/env sh
set -e
cd ~/projects/docker-builds/
ci_scripts/cleanup_docker.sh full
export BUILDKIT_PROGRESS=plain
ci_scripts/build_product.sh -p pingdownloader
ci_scripts/build_foundation.sh
ci_scripts/build_product.sh -p pingaccess -v 6.3.0-Beta -j rl11 -s redhat/ubi/ubi8:8.5
ci_scripts/build_product.sh -p pingfederate -v 10.3.0 -j rl11 -s redhat/ubi/ubi8:8.5
ci_scripts/build_product.sh -p pingdirectory -v 8.3.0.0 -j rl11 -s redhat/ubi/ubi8:8.5
