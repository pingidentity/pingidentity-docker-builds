#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# Runs a set of tests specified by the --helm-test {test-name} option.
# This script will typically be called by run_helm_smoke.sh and run_helm_integration.sh.
#
test -n "${VERBOSE}" && set -x

###############################################################################
# Usage printing function
###############################################################################
usage() {
    echo "${*}"
    cat << END_USAGE
Usage: ${0} {options}
    where {options} include:

    --helm-test {test-name}
        The name of the helm test to run.
        If single helm values yaml file, then that that file will be used
        If directory with testFramework values yaml file(s), then all those will
        be run as seperate tests.

        Available tests include (from ${_helm_tests_dir}):
$(cd "${_helm_tests_dir}" && find ./* -type d -maxdepth 2 | grep "\/" | sed 's/^/          /')

    --helm-chart {helm-chart-name}
        The name of the local helm chart to use.
        Note: Must be local, and will not download from helm.pingidentity.com

    --namespace {namespace-name}
        The name of the namespace to use.  Used primarily for local testing
        Note: The namespace must be available and it will not be deleted

    --namespace-suffix {namespace-suffix}
        Namespace suffix to be appended to namespace

    --helm-file-values {helm-values-yaml}
        Additional helm values files to be added to helm-test.
        Multiple helm values files can be added.

    --verbose
        Turn up the volume

    --keep-namespace-on-exit
        Keep the namespace on exit

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

    CI_PIPELINE_ID="local"
    CI_JOB_ID=$(date '+%Y%m%d%H%M%S')
else
    _addl_helm_set_values=" --set global.container.nodeSelector.docker-build-use=tests
                            --set testFramework.pod.nodeSelector.docker-build-use=tests"
fi

_helm_tests_dir="${CI_PROJECT_DIR}/helm-tests"

while test -n "${1}"; do
    case "${1}" in
        --helm-test)
            _test_to_run=""
            _dir_to_run=""
            test -z "${2}" && usage "You must specify a test if you specify the ${1} option"
            shift
            # Try relative path off current directory
            test -f "$(pwd)"/"${1}" && _test_to_run="$(pwd)"/"${1}"
            # Try path off _helm_tests_dir directory
            test -z "${_test_to_run}" && test -f "${_helm_tests_dir}"/"${1}" && _test_to_run="${_helm_tests_dir}"/"${1}"
            # Try absolute path
            test -z "${_test_to_run}" && test -f "${1}" && _test_to_run="${1}"

            # if we still don't have a test, let's look at directories
            if test -z "${_test_to_run}"; then
                test -d "$(pwd)"/"${1}" && _dir_to_run="$(pwd)"/"${1}"
                test -z "${_dir_to_run}" && test -d "${_helm_tests_dir}"/"${1}" && _dir_to_run="${_helm_tests_dir}"/"${1}"
                test -z "${_dir_to_run}" && test -d "${1}" && _dir_to_run="${1}"

                if test -n "${_dir_to_run}"; then
                    for _test_candidate in "${_dir_to_run}"/*.y*ml; do
                        grep "^testFramework:" "${_test_candidate}" 2> /dev/null > /dev/null

                        if test $? -eq 0; then
                            _test_to_run="${_test_to_run} ${_test_candidate}"
                        fi
                    done
                fi
            fi

            test -z "${_test_to_run}" && usage "Unable to find a file/directory for helm-test '${1}'"

            _helmTests="${_helmTests} ${_test_to_run}"
            ;;
        --helm-chart)
            test -z "${2}" && usage "You must specify a helm chart to deploy to if you specify the ${1} option"
            shift
            HELM_CHART_NAME="${1}"
            ;;
        --helm-file-values)
            test -z "${2}" && usage "You must specify a helm values yaml file if you specify the ${1} option"
            shift
            _addl_helm_file_values="${_addl_helm_file_values} -f ${1}"
            ;;
        --helm-set-values)
            test -z "${2}" && usage "You must specify a helm set values (name=value) if you specify the ${1} option"
            shift
            _addl_helm_set_values="${_addl_helm_set_values} --set ${1}"
            ;;
        --namespace)
            test -z "${2}" && usage "You must specify a namespace to deploy to if you specify the ${1} option"
            shift
            _namespace_to_use="${1}"
            ;;
        --namespace-suffix)
            test -z "${2}" && usage "You must specify a namespace-suffix to use if you specify the ${1} option"
            shift
            _namespace_suffix="${1}"
            ;;
        --verbose)
            VERBOSE=true
            ;;
        --keep-namespace-on-exit)
            HELM_KEEP_ON_EXIT=true
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

_tmpDir=$(mktemp -d)

################################################################################
# _final
################################################################################
_final() {
    #
    # If the _exitCode isn't set, then the test never finished and was probably
    # interrupted, so we will set it to 1 (i.e. error)
    #
    test -z "${_exitCode}" && _exitCode=1

    #
    # Find out if there is a release running that we need to cleanup
    #
    helm ls --filter "${_helmRelease}" "${NS_OPT[@]}" | grep "^${_helmRelease}" > /dev/null 2> /dev/null

    if test $? -eq 0; then
        #
        # If there was an error, we will print out details about the various k8s resources
        #
        if test ${_exitCode} -gt 0; then
            banner "Error (${_exitCode}) - Resources before CleanUp"
            kubectl get cm,pod,service,pvc,events "${NS_OPT[@]}"
        fi

        #
        # Uninstall the helm release
        #
        banner "CleanUp: Uninstalling Release"
        helm uninstall "${_helmRelease}" "${NS_OPT[@]}"
    fi

    if test -z "${_namespace_to_use}"; then
        if test -z "${HELM_KEEP_ON_EXIT}"; then
            banner "CleanUp: Deleting namespace ${NS}"
            kubectl delete namespace "${NS}" --wait=true
        else
            echo_red "Warning: Keeping aftifacts created (i.e. pvcs, configmaps, secrets)"
        fi
    else
        echo_red "Warning: Keeping aftifacts created (i.e. pvcs, configmaps, secrets)"
    fi

    #
    # Cat the final resultsFile
    #
    cat "${_resultsFile}"

    #
    # Calculate the total duration of the test and output that
    #
    _totalStop=$(date '+%s')
    _totalDuration=$((_totalStop - _totalStart))
    echo "Total duration: ${_totalDuration}s"

    rm -rf "${_tmpDir}"

    #
    # Finally exit with the _exitCode
    exit "${_exitCode}"
}

trap _final EXIT

################################################################################
# Build Postman Environment Variables from exiting config maps ending in argument
# passed
#
# Example:
#   getPostmanEnvJson "-env-vars"
################################################################################
getPostmanEnvJson() {
    _search="${1}"

    #
    # Get the list of candidate ConfigMap Names based on the search
    #
    _candidateCMs=$(kubectl get configmap "${NS_OPT[@]}" -o json | jq -r ".items[] | select(.metadata.name | test(\"$_search\")) | .metadata.name")

    #
    # Start the json with basic info
    #
    echo "{
        \"id\": \"9b464ada-d685-4415-8f5a-8ed2c3970d6a\",
        \"name\": \"helm-testing\",
        \"_postman_variable_scope\": \"environment\",
        \"_postman_exported_at\": \"$(date '+%Y-%m-%dT%H:%M:%S')\",
        \"_postman_exported_using\": \"helm-testing\",
        \"values\": ["

    #
    # For each candidate ConfigMap
    # Get the Name/Value pairs in the data element and create a
    # postman environment key/value/enabled json
    for _candidateCM in ${_candidateCMs}; do
        _nvPairs=$(kubectl get configmap "${_candidateCM}" "${NS_OPT[@]}" -o json | jq -r '.data')

        for _key in $(jq -r 'keys | .[]' <<< "${_nvPairs}"); do
            echo "${_comma}"
            jq -n '{key:$key,value:$value,enabled:$enabled}' \
                --arg key "${_key}" \
                --arg value "$(jq -r ".$_key" <<< "${_nvPairs}")" \
                --arg enabled "true"

            _comma=","
        done
    done

    #
    # End the Json
    #
    echo "]}"
}

################################################################################
# processContainerResults "container | initContainer"
################################################################################
processContainerResults() {
    _contType="${1}"
    _testPodName="${_helmRelease}-${TEST_SUFFIX}"

    for _icName in $(kubectl get pods "${_testPodName}" "${NS_OPT[@]}" -o json | jq -r ".status.${_contType}Statuses[] | .name"); do
        banner "Logs: ${_icName}"
        _icStatus=$(kubectl get pods "${_testPodName}" "${NS_OPT[@]}" -o json | jq -r ".status.${_contType}Statuses[] | select(.name | test(\"${_icName}\"))")

        _icExit=$(jq -r .state.terminated.exitCode <<< "${_icStatus}")
        _icReason=$(jq -r .state.terminated.reason <<< "${_icStatus}")

        if test "${_icExit}" == "0"; then
            _result="PASS"
            _icStart=$(jq -r .state.terminated.startedAt <<< "${_icStatus}")
            _icFinish=$(jq -r .state.terminated.finishedAt <<< "${_icStatus}")

            # Because date on MacOSX and Unix are different
            if test "$(uname -s)" == "Darwin"; then
                _icStart=$(date -j -f "%Y-%m-%dT%TZ" "${_icStart}" "+%s")
                _icFinish=$(date -j -f "%Y-%m-%dT%TZ" "${_icFinish}" "+%s")
            else
                _icStart=$(date -d "${_icStart}" +%s)
                _icFinish=$(date -d "${_icFinish}" +%s)
            fi

            _duration=$((_icFinish - _icStart))
        else
            banner "Describe details for test"
            kubectl describe pods "${_testPodName}" "${NS_OPT[@]}"
            _result="FAIL"
            _duration="-"
            test "${_icReason}" == "null" && _icReason="-"
        fi

        if test "${_contType}" == "initContainer"; then
            kubectl logs "${_testPodName}" "${NS_OPT[@]}" -c "${_icName}" 2> /dev/null
        else
            kubectl logs "${_testPodName}" "${NS_OPT[@]}" 2> /dev/null
        fi

        append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "  ${_icName}" "${_duration}" "${_icReason}"
    done
}

#
# Reporting Formating
#
_totalStart=$(date '+%s')
_resultsFile="${_tmpDir}/$$.results"
_headerPattern=' %-58s| %10s| %10s\n'
_reportPattern='%-57s| %10s| %10s'
# shellcheck disable=SC2059
printf "${_headerPattern}" "TEST" "DURATION" "RESULT" > "${_resultsFile}"

_exitCode=

# TEST_PREFIX used as prefix for Namespace, ReleaseName and generated configmaps
export TEST_PREFIX="dbt-"
# TEST_PREFIX used as prefix for Helm Test name
export TEST_SUFFIX="testframework"

#
# Determine the NAMESPACE to use
#
if test -n "${_namespace_to_use}"; then
    NS=$(toLower "${_namespace_to_use}")
    export NS

    kubectl get ns "${NS}" 2> /dev/null > /dev/null

    if test $? -ne 0; then
        echo_red "ERROR: Unable to use namespace provided."
        exit
    fi
else
    export NAMESPACE_PREFIX="${NAMESPACE_PREFIX:-$TEST_PREFIX}"

    NS=$(toLower "${NAMESPACE_PREFIX}${CI_COMMIT_REF_NAME:-$USER}-${CI_PIPELINE_ID}-${CI_JOB_ID}${_namespace_suffix}")
    export NS

    #
    # Create the namespace
    #
    banner "Creating namespace '${NS}'"

    kubectl create namespace "${NS}"

    if test $? -ne 0; then
        echo_red "Error: Unable to create a namespace.  Most likely a permission problem problem "
        exit
    fi
fi
export NS_OPT=(--namespace "${NS}")

#
# If we are in a pipeline, we will need to create a docker-registry secret
# with access to the pipeline repo (typically an AWS ECR)
#
test -n "${PIPELINE_BUILD_REGISTRY}" && _createPipelineRepoAccess "${NS}"

#
# Setup Helm
#
if test -z "${HELM_CHART_NAME}"; then
    export HELM_REPO_URL="${HELM_REPO_URL:-https://helm.pingidentity.com}"
    export HELM_REPO_NAME="${HELM_REPO_NAME:-pingidentity}"
    export HELM_CHART_NAME="${HELM_CHART_NAME:-$HELM_REPO_NAME/ping-devops}"
    export HELM_CHART_VERSION="${HELM_CHART_VERSION:-latest}"
fi

banner "
               Helm Details

         helm version: $(helm version)
        helm repo url: ${HELM_REPO_URL}
            helm repo: ${HELM_REPO_NAME}

           helm chart: ${HELM_CHART_NAME}
   helm chart version: ${HELM_CHART_VERSION}
"

if test -n "${HELM_REPO_URL}"; then
    helm repo add "${HELM_REPO_NAME}" "${HELM_REPO_URL}"

    if test $? -ne 0; then
        echo_red "ERROR: Unable to add helm repo ${HELM_REPO_URL}."
        exit
    fi

    helm search repo "${HELM_REPO_NAME}"
else
    if test ! -d "${HELM_CHART_NAME}"; then
        echo_red "ERROR: Unable to find local helm chart '${HELM_CHART_NAME}'"
        exit
    else
        echo "Using local helm-charts."
    fi
fi

test -n "${VERBOSE}" && kubectl get namespaces
test -n "${VERBOSE}" && banner "Describing nodes"
test -n "${VERBOSE}" && kubectl describe nodes

#
# Create the devops-secret ConfigMap
#
_devopsSecretName="devops-secret"
banner "Generating Secret ${_devopsSecretName}"
kubectl delete secret "${_devopsSecretName}" "${NS_OPT[@]}" 2> /dev/null > /dev/null
kubectl create secret generic "${_devopsSecretName}" "${NS_OPT[@]}" \
    --from-literal=PING_IDENTITY_DEVOPS_USER="${PING_IDENTITY_DEVOPS_USER}" \
    --from-literal=PING_IDENTITY_DEVOPS_KEY="${PING_IDENTITY_DEVOPS_KEY}" \
    --from-literal=PING_IDENTITY_ACCEPT_EULA="YES"

#
# Global assets to be imported for configmaps
#
_globalAssets="${_helm_tests_dir}/_global"

#
# Perform an install/test for each test
#
for _helmTest in ${_helmTests}; do
    _start=$(date '+%s')

    _helmTestDir="$(dirname "${_helmTest}")"

    _testName="$(basename "${_helmTest}" | sed 's/\.y.*ml$//')"

    _helmRelease="${TEST_PREFIX}${_testName}${_namespace_suffix}"

    banner "
                   Installing

              Helm Test:  ${_testName}
              Namespace:  ${NS}
            Values Yaml:  ${_helmTest}

             Chart Name: ${HELM_CHART_NAME}
          Chart Version: ${HELM_CHART_VERSION}
           Release Name: ${_helmRelease}

 Additional File Values: ${_addl_helm_file_values}
  Additional Set Values: ${_addl_helm_set_values}
"

    kubectl label namespace "${NS}" --overwrite \
        test-name="${_testName}"

    test -n "${HELM_CHART_VERSION}" && test "${HELM_CHART_VERSION}" != "latest" && _versionOpt="--version ${HELM_CHART_VERSION}"

    #
    # Substitute any variables (such as $DEP) into the helm test prior to installing
    #
    _substHelmTest="${_tmpDir}/${_helmRelease}"
    # shellcheck disable=SC2016
    envsubst '${DEPS_REGISTRY}' < "${_helmTest}" > "${_substHelmTest}"

    # Word-split is expected behavior for helm variables. Disable shellcheck.
    # shellcheck disable=SC2086
    helm install "${_helmRelease}" "${HELM_CHART_NAME}" \
        ${_versionOpt} \
        "${NS_OPT[@]}" \
        -f "${_substHelmTest}" \
        ${_addl_helm_file_values} \
        ${_addl_helm_set_values} \
        --set "testFramework.name=${TEST_SUFFIX}" \
        --set "testFramework.enabled=true" \
        --set "testFramework.testConfigMaps.prefix=${TEST_PREFIX}" \
        --set "testFramework.finalStep.image=${DEPS_REGISTRY}busybox" \
        --set "global.addReleaseNameToResource=prepend"

    _returnCode=${?}

    banner "Helm Release Values Provided"
    helm get values "${_helmRelease}" "${NS_OPT[@]}"

    if test ${_returnCode} -eq 0; then
        #
        # Allow a bit of time to allow for configmaps to be created so we can generate
        # the postman enviornment variables in next step
        #
        sleep 5
        #
        # Generate Postman Environment ConfigMaps
        #
        banner "Generating Postman Environment ConfigMap"

        #
        # Generate a postman style environments json file
        #
        _postmanEnvConfigMap="${_helmRelease}-generated.postman-environment.json"
        _postmanEnvFile="${_tmpDir}/${_postmanEnvConfigMap}"

        getPostmanEnvJson ".*-env-vars$" > "${_postmanEnvFile}"

        kubectl delete configmap "${_postmanEnvConfigMap}" "${NS_OPT[@]}" 2> /dev/null > /dev/null
        kubectl create configmap "${_postmanEnvConfigMap}" "${NS_OPT[@]}" --from-file="file=${_postmanEnvFile}"

        #
        # Generate ConfigMaps for all test and global
        #
        banner "Generating test & global ConfigMaps"

        for _asset in "${_helmTestDir}"/* "${_globalAssets}"/*; do
            _assetName=$(basename "${_asset}")

            _assetConfigMapName="${_helmRelease}-${_assetName}"

            kubectl delete configmap "${_assetConfigMapName}" "${NS_OPT[@]}" 2> /dev/null > /dev/null
            kubectl create configmap "${_assetConfigMapName}" "${NS_OPT[@]}" --from-file="file=${_asset}"
        done

        #
        # Get all resources before test is started
        banner "Resources available before test"
        kubectl get cm,pod,service,pvc "${NS_OPT[@]}"

        banner "Starting test..."
        helm test "${_helmRelease}" "${NS_OPT[@]}" --timeout 25m

        _returnCode=${?}

        test ${_returnCode} -ne 0 && echo_red "helm test Failed"
    else
        echo_red "helm install was unsucessful (_returnCode=${_returnCode})"

        kubectl get cm,pod,service,pvc "${NS_OPT[@]}"
    fi

    _stop=$(date '+%s')
    _duration=$((_stop - _start))

    if test ${_returnCode} -ne 0; then
        _result="FAIL"
    else
        _result="PASS"
    fi
    append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "${_helmRelease}-${TEST_SUFFIX}" "${_duration}" "${_result}"
    _exitCode=$((_exitCode + _returnCode))

    processContainerResults "initContainer"
    processContainerResults "container"
done
