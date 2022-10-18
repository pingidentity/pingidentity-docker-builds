#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdirectory.lib.sh
test -f "${HOOKS_DIR}/pingdirectory.lib.sh" && . "${HOOKS_DIR}/pingdirectory.lib.sh"

#
# If we are:
#  - kubernetes
#  - no IP is found for the $POD_HOSTNAME
# then
#  This implies that a headless service allowing for unready hosts isn't setup which is
#  required to ensure that the pingdirectory service isn't available until after all the
#  required replication has been setup.  If we don't check for this here then the
#  setup process here will fail.
_podHostName=$(getHostName)
if test "${ORCHESTRATION_TYPE}" = "KUBERNETES" &&
    test -z "$(getIP "${_podHostName}")"; then
    echo_red "Detected:
      - Container running in Kubernetes
      - The Kubernetes service providing IP for '${_podHostName}' isn't returning any value
   
        This implies that the Kubernetes service isn't providing the annotations allowing for 
        unready hosts to be discovered. 
        
        RESOLUTION - Create/Add a separate cluster service with the following annotations/spec 
        
      metadata: 
        annotations: 
          service.alpha.kubernetes.io/tolerate-unready-endpoints: true 
      spec: 
        publishNotReadyAddresses: true
    "

    container_failure 182 "Resolve issues with pingdirectory Kubernetes cluster service, and restart"
fi

#
# If we are the GENESIS state, or if we are the first pod of a non-seed cluster in an entry-balanced deployment,
# then process any templates if they are defined.
#

_ordinal="${_podHostName##*-}"
if test "${PD_STATE}" = "GENESIS" || { test -n "${RESTRICTED_BASE_DNS}" && test "${K8S_CLUSTER}" != "${K8S_SEED_CLUSTER}" && test "${_ordinal}" == "0"; }; then
    echo "PD_STATE is GENESIS ==> Processing Templates"

    test -z "${MAKELDIF_USERS}" && MAKELDIF_USERS=0

    find "${PD_PROFILE}/ldif" -maxdepth 1 -mindepth 1 -type d 2> /dev/null | while read -r _ldifDir; do
        find "${_ldifDir}" -type f -iname \*.template 2> /dev/null | while read -r _template; do
            echo "Processing (${_template}) template with ${MAKELDIF_USERS} users..."
            _generatedLdifFilename="${_template%.*}.ldif"
            "${SERVER_ROOT_DIR}/bin/make-ldif" \
                --templateFile "${_template}" \
                --ldifFile "${_generatedLdifFilename}" \
                --numThreads 3
        done
    done
else
    echo "PD_STATE is not GENESIS ==> Skipping Templates"
    echo "PD_STATE is not GENESIS ==> Will not process ldif imports"

    # GDO-191 - Following is used by 183-run-setup.sh.  Appended to CONTAINER_ENV, to allow for that
    # hook to pick it up
    _skipImports="--skipImportLdif"

    # next line is for shellcheck disable to ensure $RUN_PLAN is used
    echo "${_skipImports}" >> /dev/null

    export_container_env _skipImports
fi

appendTemplatesToVariablesIgnore
