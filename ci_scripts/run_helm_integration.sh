#!/usr/bin/env bash
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - CI scripts
#
# Runs integration tests located in integration_tests directory
#
test "${VERBOSE}" = "true" && set -x

###############################################################################
# Usage printing function
###############################################################################
usage() {
    echo "${*}"
    cat << END_USAGE
Usage: ${0} {options}
    where {options} include:

    --integration-test {integration-test-name}
        ** Required
        The name of the integration test to run.  Should be a directory
        in current directory, relative directory off of helm-tests/integration-tests
        or absolute directory.  The directory should contain yaml files containing
        helm chart values.

        Available tests include (from ${_integration_helm_tests_dir}):
$(cd "${_integration_helm_tests_dir}" && find ./* -type d -maxdepth 1 | sed 's/^/          /')

    --variation {id}
        ** Required, unless the image tag is overridden.
        Select the integration test variation configuration as described in
        helm-tests/integration-tests/integration-tests.json for the provided test name.

    --namespace {namespace-name}
        The name of the namespace to use.  Used primarily for local testing
        Note: The namespace must be available and it will not be deleted

    --helm-chart {helm-chart-name}
        The name of the local helm chart to use.
        Note: Must be local, and will not download from helm.pingidentity.com

    --helm-file-values {helm-values-yaml}
        Additional helm values files to be added to helm-test.
        Multiple helm values files can be added.

    --image-tag-override {tag}
        Override the image-tags with this single tag.  Good for testing against a released
        version (i.e. sprint of 2105)

    --verbose
        Turn up the volume

    -h|--help
        Display general usage information
END_USAGE
    exit 99
}

#
# Determine if we are local or part of a CI/CD Pipeline
#
if test -z "${CI_COMMIT_REF_NAME}"; then
    CI_PROJECT_DIR="$(
        cd "$(dirname "${0}")/.." || exit 97
        pwd
    )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi

_tmpDir=$(mktemp -d)
_integration_helm_tests_dir="${CI_PROJECT_DIR}/helm-tests/integration-tests"

while test -n "${1}"; do
    case "${1}" in
        --integration-test)
            _integration_to_run=""
            test -z "${2}" && usage "You must specify a test if you specify the ${1} option"
            shift
            # Try relative path off current directory
            test -d "$(pwd)"/"${1}" && _integration_to_run="$(pwd)"/"${1}"
            # Try path off _integration_helm_tests_dir directory
            test -z "${_integration_to_run}" && test -d "${_integration_helm_tests_dir}"/"${1}" && _integration_to_run="${_integration_helm_tests_dir}"/"${1}"
            # Try absolute path
            test -z "${_integration_to_run}" && test -d "${1}" && _integration_to_run="${1}"

            test -z "${_integration_to_run}" && usage "Unable to find a directory for integration-test '${1}'"
            ;;
        --helm-chart)
            test -z "${2}" && usage "You must specify a helm chart to deploy to if you specify the ${1} option"
            shift
            HELM_CHART_NAME="${1}"
            ;;
        --helm-file-values)
            test -z "${2}" && usage "You must specify a helm values yaml file if you specify the ${1} option"
            shift
            _addl_helm_file_values=("${_addl_helm_file_values[@]}" --helm-file-values "${1}")
            ;;
        --helm-set-values)
            test -z "${2}" && usage "You must specify a helm set values (name=value) if you specify the ${1} option"
            shift
            _addl_helm_set_values=("${_addl_helm_set_values[@]}" --helm-set-values "${1}")
            ;;
        --image-tag-override)
            test -z "${2}" && usage "You must specify an image-tag-override ${1} option (i.e. 2105)"
            shift
            _image_tag_override="${1}"
            ;;
        --namespace)
            test -z "${2}" && usage "You must specify a namespace to deploy to if you specify the ${1} option"
            shift
            _namespace_to_use="${1}"
            ;;
        --variation)
            test -z "${2}" && usage "You must specify a variation id if you specify the ${1} option"
            shift
            variation_id="${1}"
            ;;
        --verbose)
            VERBOSE=true
            ;;
        -h | --help)
            usage
            ;;
        *)
            echo "Unrecognized option"
            usage
            ;;
    esac
    shift
done

CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

test -z "${PING_IDENTITY_DEVOPS_USER}" && usage "Env Variable PING_IDENTITY_DEVOPS_USER is required"
test -z "${PING_IDENTITY_DEVOPS_KEY}" && usage "Env Variable PING_IDENTITY_DEVOPS_KEY is required"

################################################################################
# _final
################################################################################
_final() {
    cat "${_resultsFile}"
    rm -f "${_resultsFile}"
    rm -rf "${_tmpDir}"
    _totalStop=$(date '+%s')
    _totalDuration=$((_totalStop - _totalStart))
    echo "Total duration: ${_totalDuration}s"
    test -n "${_exitCode}" && exit "${_exitCode}"

    # no test were run, this is likely an issue
    exit 1
}

trap _final EXIT

_exitCode=""

################################################################################
# _create_helm_values
################################################################################
_create_helm_values() {
    banner "Creating image/tags to use"

    _imagePattern=' %-58s| %-15s\n'
    #shellcheck disable=SC2059
    printf "$_imagePattern" "IMAGE" "TAG"

    if test -n "${_image_tag_override}"; then
        _tag="${_image_tag_override}"
    else
        # Start out the tag with the version of the product being built
        test -z "${product_version}" && echo_red "ERROR: version for product ${_productName} not found." && exit 1
        _tag="${product_version}"

        # Add the shim (i.e. os) to the tag.  Example: alpine
        test -z "${shim_long_tag}" && echo_red "ERROR: Shim for product ${_productName} not found." && exit 1
        _tag="${_tag}-${shim_long_tag}"

        # Add the jvm to the tag.  Example: al11
        test -z "${jvm_id}" && echo_red "ERROR: JVM for product ${_productName} not found." && exit 1
        _tag="${_tag}-${jvm_id}"

        # CI_TAG is assigned when we source ci_tools.lib.sh (i.e. run in pipeline)
        test -z "${CI_TAG}" && echo_red "ERROR: CI_TAG not found." && exit 1
        _tag="${_tag}-${CI_TAG}"

        #Finally, add the architecture designation to the tag
        test -z "${test_arch}" && echo_red "ERROR: Test architecture not found." && exit 1
        _tag="${_tag}-${test_arch}"
    fi

    #shellcheck disable=SC2059
    printf "$_imagePattern" "${FOUNDATION_REGISTRY}/${_productName}" "${_tag}"
    cat >> "${_helmValues}" << EO_PROD_TAG
${_productName}:
  image:
    name: ${short_product_name}
    repository: ${FOUNDATION_REGISTRY}
    tag: ${_tag}
    pullPolicy: Always

EO_PROD_TAG

}

test -z "${_integration_to_run}" && usage "Integration test name is required, but not specified."
test -z "${variation_id}" && test -z "${_image_tag_override}" && usage "Test variation id is required, but not specified."

integration_test_name="${_integration_to_run##*/}"

# Get the defined architecture for the test
test_arch=$(_getIntTestArch "${integration_test_name}" "${variation_id}")

# Get the defined architecture for the test
platform=$(_getIntTestPlatform "${integration_test_name}" "${variation_id}")

# Get the defined products for the test
products=$(_getIntTestProducts "${integration_test_name}" "${variation_id}")

_helmValues="${_tmpDir}/helmValues.yaml"
for _productName in ${products}; do
    short_product_name="$(echo "${_productName}" | sed -e "s/-admin//" -e "s/-engine//")"
    # Get the defined JVM ID for the product.
    jvm_id=$(_getIntTestProductJVM "${integration_test_name}" "${variation_id}" "${_productName}")

    # Get the defined shim for the product.
    shim_tag=$(_getIntTestProductShim "${integration_test_name}" "${variation_id}" "${_productName}")
    shim_long_tag=$(_getLongTag "${shim_tag}")

    #If this is a snapshot pipeline, override the image tag to snapshot image tags
    # Get the defined product version.
    if test -n "${PING_IDENTITY_SNAPSHOT}"; then
        # Get the defined product version.
        # If the product version is set to latest, grab the latest product version.
        product_version="$(_getLatestSnapshotVersionForProduct "${short_product_name}")"
        _image_tag_override="${product_version}-${shim_long_tag}-${jvm_id}-${CI_TAG}-${test_arch}"
    else
        product_version="$(_getIntTestProductVersion "${integration_test_name}" "${variation_id}" "${_productName}")"
        # If the product version is set to latest, grab the latest product version.
        if test "${product_version}" = "latest"; then
            product_version=$(_getLatestVersionForProduct "${short_product_name}")
        fi
    fi
    _create_helm_values
done

if test "${platform}" = "openshift"; then
    echo "This is an integration-test on an openshift cluster"
    # Switch to openshift cluster context in order to run integration tests on redhat images
    kubectl config set-cluster "${RH_CLUSTER}" --server="${RH_CLUSTER_SERVER}"
    kubectl config set "clusters.${RH_CLUSTER}.certificate-authority-data" "${RH_CLUSTER_CERT}"
    kubectl config set-context "${_namespace_to_use}/${RH_CLUSTER}/system:admin" --cluster="${RH_CLUSTER}" --namespace="${_namespace_to_use}" --user="system:admin/${RH_CLUSTER}"
    kubectl config set "users.system:admin/${RH_CLUSTER}.client-certificate-data" "${RH_CLUSTER_CLIENT_CERT}"
    kubectl config set "users.system:admin/${RH_CLUSTER}.client-key-data" "${RH_CLUSTER_CLIENT_KEY}"
    kubectl config use-context "${_namespace_to_use}/${RH_CLUSTER}/system:admin"

    # Unset fsGroup and runAsUser on pod and container level
    _addl_helm_set_values=("${_addl_helm_set_values[@]}" --helm-set-values "global.workload.securityContext.fsGroup=null")
    _addl_helm_set_values=("${_addl_helm_set_values[@]}" --helm-set-values "global.workload.securityContext.runAsUser=null")
    _addl_helm_set_values=("${_addl_helm_set_values[@]}" --helm-set-values "global.externalImage.pingtoolkit.securityContext.runAsUser=null")
    _addl_helm_set_values=("${_addl_helm_set_values[@]}" --helm-set-values "global.externalImage.pingaccess.securityContext.runAsUser=null")
fi

# Create result file information/patterns
_totalStart=$(date '+%s')
_resultsFile="/tmp/$$.results"
_headerPattern=' %-58s| %10s| %10s\n'
_reportPattern='%-57s| %10s| %10s'

test -n "${VERBOSE}" && banner "kubectl describe nodes"
test -n "${VERBOSE}" && kubectl describe nodes

test -n "${VERBOSE}" && banner "kubectl get pods --all-namespaces"
test -n "${VERBOSE}" && kubectl get pods --all-namespaces

banner "Running ${_integration_to_run} integration test"

# shellcheck disable=SC2059
printf "${_headerPattern}" "TEST" "DURATION" "RESULT" > ${_resultsFile}

_start=$(date '+%s')

test -n "${_namespace_to_use}" && NS_OPT=(--namespace "${_namespace_to_use}")
test -n "${HELM_CHART_NAME}" && HELM_CHART_OPT=(--helm-chart "${HELM_CHART_NAME}")
"${CI_SCRIPTS_DIR}/run_helm_tests.sh" \
    --helm-test "${_integration_to_run}" \
    --platform "${platform}" \
    --helm-file-values "${_helmValues}" \
    "${_addl_helm_file_values[@]}" \
    "${_addl_helm_set_values[@]}" \
    "${NS_OPT[@]}" \
    "${HELM_CHART_OPT[@]}"

_exitCode=${?}
_stop=$(date '+%s')
_duration=$((_stop - _start))

# Unset openshift cluster context
if test "${platform}" = "openshift"; then
    kubectl config unset "contexts.redhat-cluster/${RH_CLUSTER}/system:admin"
    kubectl config unset "clusters.${RH_CLUSTER}"
    kubectl config unset "users.system:admin/${RH_CLUSTER}"
fi

# Remove daemonSet
if test -n "$(kubectl get daemonsets.apps haveged --namespace default 2>&1 > /dev/null)"; then
    kubectl delete -n default daemonsets.apps haveged
fi

if test ${_exitCode} -ne 0; then
    _result="FAIL"
else
    _result="PASS"
fi
append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "${_integration_to_run}" "${_duration}" "${_result}"
