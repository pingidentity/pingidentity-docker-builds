#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=/dev/null
test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"
# shellcheck source=pingdirectory.lib.sh
test -f "${HOOKS_DIR}/pingdirectory.lib.sh" && . "${HOOKS_DIR}/pingdirectory.lib.sh"

# This script will remove the server from the topology for any graceful
# termination, i.e. scale-down and rolling-update when invoked from a pre-stop
# hook. Ideally, the server is not removed from the topology in the rolling
# update case. However, when using an orchestration framework like Kubernetes,
# the pod that the container is running on has no way of knowing why it's going
# down unless it can find this information from an external source (e.g. a
# topology.json file uploaded to an S3 bucket). A topology.json file provided
# through a config-map mounted volume will not do because that will change the
# pod spec and re-spin --all-- of the pods unnecessarily, even if the only
# change to the deployment is a reduced replica count.
INSTANCE_NAME=$(dsconfig --no-prompt \
  --useSSL --trustAll \
  --hostname "${HOSTNAME}" --port "${LDAPS_PORT}" \
  get-global-configuration-prop \
  --property instance-name \
  --script-friendly |
  awk '{ print $2 }')

echo "Removing ${HOSTNAME} (instance name: ${INSTANCE_NAME}) from the topology"
remove-defunct-server --no-prompt \
  --serverInstanceName "${INSTANCE_NAME}" \
  --retryTimeoutSeconds ${RETRY_TIMEOUT_SECONDS} \
  --ignoreOnline \
  --bindDN "${ROOT_USER_DN}" \
  --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
  --enableDebug --globalDebugLevel verbose
echo "Server removal exited with return code: $?"