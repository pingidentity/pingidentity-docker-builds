#!/usr/bin/env sh
${VERBOSE} && set -x

#
# This script is started in the background immediately before 
# the server within the container is started
#
# This is useful to implement any logic that needs to occur after the
# server is up and running
# For example, enabling replication in PingDirectory, initializing Sync 
# Pipes in PingDataSync or issuing admin API calls to PingFederate or PingAccess