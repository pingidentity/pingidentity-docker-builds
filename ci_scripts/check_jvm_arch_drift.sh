#!/usr/bin/env bash
# PDI-2521 AC: assert every jvm id in ci_scripts/jvms.json publishes base
# images for all the archs the catalog claims. Drift check — run manually or
# from CI; exits non-zero when the catalog claims an arch the registry does
# not serve for that id.
#
# The base image mapping is single-sourced from ci_tools.lib.sh
# _getBaseImageForJVM (sourced below) — this checker cannot drift from it.
# Talks to the registry's v2 API directly (token auth + manifest index GET):
# docker manifest inspect also follows blobs, and the registry intermittently
# drops those connections, which makes the docker CLI path flaky.
#
# Usage: ci_scripts/check_jvm_arch_drift.sh [registry]
#   registry defaults to ${ARTIFACTORY_REGISTRY:-docker.corp.pingidentity.com:5300}
# Requires: curl, jq, and network access to the registry.

test "${VERBOSE}" = "true" && set -x

if test -z "${CI_PROJECT_DIR}"; then
    CI_PROJECT_DIR="$(
        cd "$(dirname "${0}")/.." || exit 97
        pwd
    )"
fi

_registry="${1:-${ARTIFACTORY_REGISTRY:-docker.corp.pingidentity.com:5300}}"
_catalog="${CI_PROJECT_DIR}/ci_scripts/jvms.json"
_manifestFile="${TMPDIR:-/tmp}/$$.jvm-arch-drift-manifest.json"

# Single source of truth for the base image mapping. _getBaseImageForJVM echoes
# [registry/]repo:tag and exits non-zero for unmapped ids (fail closed).
# Sourced before the catalog check so echo_red is available for it.
# shellcheck source=ci_tools.lib.sh
. "${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh"

! test -f "${_catalog}" && echo_red "ERROR: File ${_catalog} not found." && exit 1

# Extract the registry-less repo and tag from _getBaseImageForJVM's output.
_baseRepoTagForJVM() {
    _rt_image="$(_getBaseImageForJVM "${1}")" || return 1
    _rt_image="${_rt_image#"${ARTIFACTORY_REGISTRY}"/}"
    printf "%s" "${_rt_image}"
}

# Fetch the manifest index for repo:tag; retry — the registry intermittently
# drops connections. Echoes the body, returns non-zero when all attempts fail.
# The Bearer token must never reach xtrace output: VERBOSE=true's set -x prints
# expanded argv, so the authenticated request runs with xtrace suppressed
# (VERBOSE is captured first so tracing resumes for everything else).
# Sets _fetch_manifest_error to "auth" (token endpoint failed) or "manifest"
# (tag missing / registry unreachable) so callers can distinguish.
_fetch_manifest() {
    _fm_repo="${1}"
    _fm_tag="${2}"
    _fm_bodyFile="${3}"
    _fm_verbose="${VERBOSE:-}"
    _fetch_manifest_error="auth"
    _fm_token=""
    for _attempt in 1 2 3; do
        _fm_token="$(curl -s --max-time 30 --fail "https://${_registry}/v2/token?scope=repository:${_fm_repo}:pull" | jq -r '.token // empty' 2> /dev/null)"
        if test -z "${_fm_token}" && test ${_attempt} -eq 3; then
            return 1
        fi
        test "${_fm_verbose}" = "true" && set +x
        curl -s --max-time 30 --fail \
            -H "Authorization: Bearer ${_fm_token}" \
            -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json" \
            "https://${_registry}/v2/${_fm_repo}/manifests/${_fm_tag}" \
            > "${_fm_bodyFile}" 2> /dev/null
        _fm_rc=${?}
        test "${_fm_verbose}" = "true" && set -x
        if test "${_fm_rc}" -eq 0; then
            return 0
        fi
        # Authenticated call got past the token endpoint: a failure here is
        # the manifest request itself, not auth.
        _fetch_manifest_error="manifest"
        sleep 3
    done
    return 1
}

# A single-platform tag returns a plain image manifest (no .manifests[]);
# normalize it into a one-entry index so the arch check applies uniformly.
_normalize_manifest() {
    _nm_file="${1}"
    if jq -e 'has("manifests")' "${_nm_file}" > /dev/null 2>&1; then
        return 0
    fi
    jq '{manifests: [{platform: {os: "linux", architecture: (.architecture // "unknown")}}]}' "${_nm_file}" > "${_nm_file}.norm" 2> /dev/null &&
        mv "${_nm_file}.norm" "${_nm_file}"
}

_returnCode=0
while IFS=$'\t' read -r jvm_id arch; do
    if ! _rt="$(_baseRepoTagForJVM "${jvm_id}")"; then
        echo_red "FAIL: ${jvm_id} has no base image mapping (catalog id out of sync with _getBaseImageForJVM)."
        _returnCode=1
        continue
    fi
    _repo="${_rt%%:*}"
    _tag="${_rt#*:}"
    # Registry-arch name docker reports for our canonical arch names.
    case "${arch}" in
        x86_64) _platform="linux/amd64" ;;
        aarch64) _platform="linux/arm64" ;;
        *) _platform="linux/${arch}" ;;
    esac
    if ! _fetch_manifest "${_repo}" "${_tag}" "${_manifestFile}"; then
        if test "${_fetch_manifest_error}" = "auth"; then
            echo_red "FAIL: registry auth failed for ${_repo}:${_tag} (token endpoint after retries)."
        else
            echo_red "FAIL: cannot fetch manifest ${_repo}:${_tag} (tag missing or registry unreachable after retries)."
        fi
        _returnCode=1
        continue
    fi
    _normalize_manifest "${_manifestFile}"
    if jq -e --arg p "${_platform}" \
        '.manifests[] | select((.platform.os + "/" + .platform.architecture) == $p)' \
        "${_manifestFile}" > /dev/null 2>&1; then
        echo "PASS: ${jvm_id} ${arch} -> ${_repo}:${_tag} serves ${_platform}"
    else
        echo_red "FAIL: ${jvm_id} claims ${arch} but ${_repo}:${_tag} has no ${_platform} manifest."
        _returnCode=1
    fi
done < <(jq -r '.jvms[] | .id as $id | .archs[] | "\($id)\t\(.)"' "${_catalog}")

exit "${_returnCode}"
