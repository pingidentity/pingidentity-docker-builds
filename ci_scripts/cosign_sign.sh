#!/usr/bin/env bash
# Copyright © 2026 Ping Identity Corporation
# Sign a container image reference with cosign + AWS KMS.
# Usage (CLI):   cosign_sign.sh [--dry-run] <image-ref> [<docker-config-dir>]
# Usage (lib):   . cosign_sign.sh; cosign_sign_image <image-ref> [<docker-config-dir>]
#
# Env: COSIGN_KEY_URI, COSIGN_KEY_LABEL, COSIGN_KEY_FINGERPRINT_SHA256 (required),
#      SIGNING_ENABLED (optional, default "true"; "false" short-circuits).

CI_SCRIPTS_DIR="${CI_SCRIPTS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
COSIGN_SIGNING_CONFIG="${COSIGN_SIGNING_CONFIG:-${CI_SCRIPTS_DIR}/cosign/signing-config.json}"
__COSIGN_PREFLIGHT_DONE="${__COSIGN_PREFLIGHT_DONE:-0}"

# One-shot preflight: verify cosign is on PATH and the configured KMS key is reachable.
# Memoized so a script that signs multiple images only pays this cost once.
_cosign_preflight() {
    test "${__COSIGN_PREFLIGHT_DONE}" = "1" && return 0

    command -v cosign > /dev/null ||
        {
            echo "ERROR: cosign not found on PATH" >&2
            return 1
        }
    cosign version > /dev/null

    if command -v aws > /dev/null; then
        # COSIGN_KEY_URI looks like: awskms:///arn:aws:kms:us-west-2:574…:key/<id>
        local key_id="${COSIGN_KEY_URI##*key/}"
        aws kms describe-key --key-id "${key_id}" --region us-west-2 > /dev/null ||
            {
                echo "ERROR: kms:DescribeKey failed for ${key_id} — check IAM" >&2
                return 1
            }
    fi

    __COSIGN_PREFLIGHT_DONE=1
    export __COSIGN_PREFLIGHT_DONE
}

cosign_sign_image() {
    local ref="${1:?cosign_sign_image: image reference required}"
    local docker_config_dir="${2:-}"
    local dry_run="${3:-}"

    if test "${SIGNING_ENABLED:-true}" != "true"; then
        echo "INFO: SIGNING_ENABLED=${SIGNING_ENABLED:-}; skipping cosign sign of ${ref}"
        return 0
    fi

    : "${COSIGN_KEY_URI:?COSIGN_KEY_URI must be set}"
    : "${COSIGN_KEY_LABEL:?COSIGN_KEY_LABEL must be set}"
    : "${COSIGN_KEY_FINGERPRINT_SHA256:?COSIGN_KEY_FINGERPRINT_SHA256 must be set}"
    test -f "${COSIGN_SIGNING_CONFIG}" ||
        {
            echo "ERROR: missing signing config ${COSIGN_SIGNING_CONFIG}" >&2
            return 1
        }

    _cosign_preflight

    local cmd=(
        cosign sign
        --yes
        --key "${COSIGN_KEY_URI}"
        --signing-config "${COSIGN_SIGNING_CONFIG}"
        -a "signer.key.label=${COSIGN_KEY_LABEL}"
        -a "signer.key.fingerprint.sha256=${COSIGN_KEY_FINGERPRINT_SHA256}"
        "${ref}"
    )

    if test -n "${dry_run}"; then
        echo "DRY-RUN: DOCKER_CONFIG=${docker_config_dir:-<default>} ${cmd[*]}"
        return 0
    fi

    echo "INFO: signing ${ref} with ${COSIGN_KEY_LABEL}"
    if test -n "${docker_config_dir}"; then
        DOCKER_CONFIG="${docker_config_dir}" AWS_REGION=us-west-2 "${cmd[@]}"
    else
        AWS_REGION=us-west-2 "${cmd[@]}"
    fi
}

# CLI entry — strict mode only here so sourcing the file doesn't propagate flags
# to the caller's shell (existing scripts are not strict-safe).
if test "${BASH_SOURCE[0]}" = "${0}"; then
    set -euo pipefail
    dry=""
    if test "${1:-}" = "--dry-run"; then
        dry=1
        shift
    fi
    cosign_sign_image "${1:?image reference required}" "${2:-}" "${dry}"
fi
