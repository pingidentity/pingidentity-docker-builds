#!/usr/bin/env bash
# sync_portal_docs.sh — Mirror generated docs into the Developer Portal repo
# (docs-devops-getting-started).
#
# Runs ci_scripts/deploy_docs.sh, then rsync-mirrors the generated docker-images
# pages into a local clone of the portal repo. Full mirror: pages added here are
# copied; pages removed here are pruned there. The portal working tree only —
# no branch, no commit, no push (publish_portal_docs.sh wraps those steps).
#
# Usage:
#   ci_scripts/sync_portal_docs.sh [--regen] [--dry-run] [PORTAL_REPO]
#
#   --regen      Run deploy_docs.sh before syncing (default: reuse existing
#                output under ${TMPDIR}/docker-images).
#   --dry-run    Show what would change; write nothing.
#   PORTAL_REPO  Path to a local clone of docs-devops-getting-started
#                (required). May also be set via DOCS_PORTAL_REPO env var.
#
# Environment:
#   DOCS_OUTPUT_DIR    Where deploy_docs.sh stages generated pages
#                      (default: script default, ${TMPDIR:-/tmp}).
#   DOCS_PORTAL_REPO   Path to the portal clone. Resolution order:
#                      positional arg > this var > ci_scripts/.env
#                      (gitignored; see ci_scripts/.env.example).

# Repo scripts avoid set -e; check return codes explicitly.
REGEN=0
DRY_RUN=0
PORTAL_REPO_ARG=""

while test -n "${1}"; do
    case "${1}" in
        --regen) REGEN=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --help | -h)
            sed -n '2,30p' "${0}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            if test -z "${PORTAL_REPO_ARG}"; then
                PORTAL_REPO_ARG="${1}"
            else
                echo "Unrecognized option: ${1}"
                exit 1
            fi
            ;;
    esac
    shift
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source local paths (DOCS_PORTAL_REPO etc.) if present
ENV_FILE="${REPO_ROOT}/ci_scripts/.env"
# shellcheck source=/dev/null
test -f "${ENV_FILE}" && . "${ENV_FILE}"

PORTAL_REPO="${PORTAL_REPO_ARG:-${DOCS_PORTAL_REPO:-}}"
if test -z "${PORTAL_REPO}"; then
    echo "ERROR: portal repo path is required."
    echo "       Pass it as a positional argument or set DOCS_PORTAL_REPO."
    exit 1
fi
if test ! -d "${PORTAL_REPO}/.git"; then
    echo "ERROR: not a git repo: ${PORTAL_REPO}"
    exit 1
fi
PORTAL_DIR="$(cd "${PORTAL_REPO}" && pwd)"

GEN_DIR="${DOCS_OUTPUT_DIR:-${TMPDIR:-/tmp}}/docker-images"
PORTAL_PAGES="${PORTAL_DIR}/asciidoc/modules/ROOT/pages/docker-images"

echo "Repo       : ${REPO_ROOT}"
echo "Portal repo: ${PORTAL_DIR}"
echo "Generated  : ${GEN_DIR}"
test "${DRY_RUN}" -eq 1 && echo "(dry-run: no files will be written)"
echo

if test "${REGEN}" -eq 1; then
    echo "==> Regenerating docs"
    # Generators write to ${TMPDIR}; must run outside the sandbox-friendly cwd
    # assumptions, hence the explicit OUTPUT_DIR pass-through.
    OUTPUT_DIR="${DOCS_OUTPUT_DIR:-${TMPDIR:-/tmp}}" DOCKER_BUILD_DIR="${REPO_ROOT}" \
        bash "${REPO_ROOT}/ci_scripts/deploy_docs.sh"
    echo
fi

if test ! -d "${GEN_DIR}"; then
    echo "ERROR: generated docs not found: ${GEN_DIR}"
    echo "       Run with --regen (or run ci_scripts/deploy_docs.sh first)."
    exit 1
fi

if test ! -d "${PORTAL_PAGES}"; then
    echo "ERROR: portal docker-images pages not found: ${PORTAL_PAGES}"
    exit 1
fi

# --- Full mirror: add + overwrite + prune stale ------------------------------
# The mirror is scoped to the per-image subdirectories only; hand-owned
# top-level pages (dockerImagesRef.adoc, imageSupport.adoc, ...) live in the
# same portal dir and must survive. Prune stale image dirs explicitly
# (rsync --delete is unsafe here — it would remove those hand-owned pages).
echo "==> Mirroring docker-images pages"
RSYNC_FLAGS=(-a --delete --include='*/' --exclude='*')
test "${DRY_RUN}" -eq 1 && RSYNC_FLAGS+=(--dry-run -v)
rsync "${RSYNC_FLAGS[@]}" "${GEN_DIR}/" "${PORTAL_PAGES}/"

for _gen_dir in "${GEN_DIR}"/*/; do
    test -d "${_gen_dir}" || continue
    _image="$(basename "${_gen_dir}")"
    if test ! -d "${PORTAL_PAGES}/${_image}"; then
        echo "==> Adding new image dir: ${_image}"
        test "${DRY_RUN}" -ne 1 && mkdir -p "${PORTAL_PAGES}/${_image}"
    fi
    RSYNC_IMG_FLAGS=(-a --delete)
    test "${DRY_RUN}" -eq 1 && RSYNC_IMG_FLAGS+=(--dry-run -v)
    rsync "${RSYNC_IMG_FLAGS[@]}" "${_gen_dir}" "${PORTAL_PAGES}/${_image}/"
done

if test "${DRY_RUN}" -eq 1; then
    for _portal_dir in "${PORTAL_PAGES}"/*/; do
        test -d "${_portal_dir}" || continue
        _image="$(basename "${_portal_dir}")"
        if test ! -d "${GEN_DIR}/${_image}"; then
            echo "pruning stale image dir: ${_image}/"
        fi
    done
fi

if test "${DRY_RUN}" -ne 1; then
    CHANGED=$(git -C "${PORTAL_DIR}" status --porcelain -- asciidoc/modules/ROOT/pages/docker-images | wc -l | tr -d ' ')
    if test "${CHANGED}" -eq 0; then
        echo "Portal docs already current; nothing to sync."
    else
        echo "Synced. ${CHANGED} path(s) changed in the portal working tree."
        echo "Review the diff, then run ci_scripts/publish_portal_docs.sh to build + PR."
    fi
fi
