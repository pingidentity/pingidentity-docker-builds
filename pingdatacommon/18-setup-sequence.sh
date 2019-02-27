#!/usr/bin/env sh
set -x

# shellcheck source=../pingcommon/lib.sh
. "${BASE}/lib.sh"

 if test ! -f "${SERVER_ROOT_DIR}/config/server.uuid" ; then
    # check the license file is present
    run_if present "${HOOKS_DIR}/181-check-license.sh" || exit 181

    # setup the instance given all the provided data
    run_if present "${HOOKS_DIR}/183-run-setup.sh" || exit 183

    # generate the topology descriptor
    run_if present "${HOOKS_DIR}/184-generate-topology-descriptor.sh" || exit 184

    # apply the tools properties for convenience
    run_if present "${HOOKS_DIR}/185-apply-tools-properties.sh" || exit 185

    # install custom extension provided
    run_if present "${HOOKS_DIR}/186-install-extensions.sh" || exit 186

    # this hook might be used to expand configuration templates
    # before they are applied in the next step
    run_if present "${HOOKS_DIR}/187-before-configuration.sh" || exit 187

    # apply custom configuration provided
    run_if present "${HOOKS_DIR}/188-apply-configuration.sh" || exit 188

    # ingest data
    run_if present "${HOOKS_DIR}/189-import-data.sh" || exit 189
  fi