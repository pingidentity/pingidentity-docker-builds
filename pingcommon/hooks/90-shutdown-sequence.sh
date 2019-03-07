#!/usr/bin/env sh
${VERBOSE} && set -x

#
# This script may be implemented to gracefully shutdown the container
# Note: this is most useful in Kubernetes but can be called arbitrarily by
#       by control/config frameworks