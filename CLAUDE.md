# docker-builds

Docker build contexts, Helm tests, and CI scripts for Ping Identity products.

Lives on GitLab (`devops-program/docker-builds`); mirrored to GitHub
(`pingidentity/pingidentity-docker-builds`) by `ci_scripts/push_to_github.sh` on tag.

## Repository map

- `ci_scripts/` — CI helpers, build entry points, integration test runners.
- `helm-tests/` — `integration-tests/`, `smoke-tests/`, `_global/`.
- `pingbase`, `pingcommon`, `pingdatacommon`, `pingjvm` — foundation layers.
- `ping*`, `ldap-sdk-tools/`, `apache-jmeter/`, `pingtoolkit/` — product build contexts.
- `shared-configs/` — submodule (`ping-internal/cdi-shared-configs`), pinned to a release
  tag. Provides release-note tooling only. Do not edit in place.

## Product architecture

Foundation layers are dependencies of product images; changes to them affect all
downstream products. Build order is foundation → products.

Standard product directory: `Dockerfile`, `versions.json`, `README.md`, `opt/`, `tmp/`,
optional `tests/`.

Entry points:

- `ci_scripts/build_foundation.sh` — base layers (`pingbase`/`pingcommon`/
  `pingdatacommon`/`pingjvm`).
- `ci_scripts/build_product.sh` — single product.
- `ci_scripts/serial_build.sh` — sequenced builds.
- `ci_scripts/build_custom_image.sh` — one-off custom product/JVM/shim builds.

## Version management

`versions.json` drives the build matrix. Validate JSON strictly before committing.

Product schema — `versions[]`, each entry with `version`, `preferredShim`, `shims[]`:

- each shim: `shim` (base image with tag), `preferredJVM`, `jvms[]`
- each jvm: `jvm` (e.g. `al21`, `rl21`), `build` (bool), `deploy` (bool),
  `registries[]` (e.g. `["DockerHub"]`)
- top-level `latest` key — check whether it needs updating alongside a version bump

`preferredShim`/`preferredJVM` are the defaults for automated builds.

`pingjvm/versions.json` has a different schema: `versions[]` of
`{id, version, shims[], archs[]}`. Its `id` values are the JVM ids products reference.
`ci_scripts/ci_tools.lib.sh` `_getAllJVMs` validates any `--jvm` against this file, so an
id used anywhere else must exist here.

JDK tracks (`pingjvm/build-jvm.sh` case blocks): 17, 21, 25. **21 is the default and
every shipping product uses `al21`/`rl21`.** 17 and 25 exist for `CUSTOM_JVM_ID` builds
only — no product `versions.json` or `helm-tests/integration-tests/integration-tests.json`
references them.

Shim base images are pinned in `ci_scripts/build_foundation.sh`
(`LATEST_ALPINE_VERSION`, the `redhat/ubi9-minimal:` tag). Changing a shim affects
supply-chain posture; keep pins explicit and never use `latest`.

## Shell script conventions

- 24 of 28 `ci_scripts/*.sh` are `#!/usr/bin/env bash`; 4 are `#!/usr/bin/env sh`
  (POSIX — no bashisms). Match the file you are editing.
- These scripts do **not** use `set -euo pipefail` as a rule; they check return codes
  explicitly and use `test x && cmd` chains. Do not add `set -e` to an existing script.
- Format and lint via the wrappers, not the bare binaries:
  `ci_scripts/shfmt.sh --diff --file <path>`, `ci_scripts/shfmt.sh -w --file <path>`,
  `ci_scripts/shellcheck.sh`. They run inside the runner container.
- Prefer tools already in use: sh/bash, sed, awk, jq, perl. Do not add a new runtime
  dependency (language runtime, OS package) without approval.
- Keep stdout/stderr stable — CI parses it. Add output only when necessary.

## Change safety

- Preserve behavior by default. Do not alter ports, image tags, registries, or security
  contexts unless asked.
- Branch names must contain **no slashes** — CI uses the branch name as the Docker image
  tag.
- No secrets. Use existing environment variables or documented inputs.
- macOS ships bash 3.2: no `declare -A`, `mapfile`, or namerefs in local tooling.

## Docker guidelines

- Minimize layers; combine `RUN` commands where logical.
- Clean apk/microdnf caches in the same layer.
- Preserve existing `USER` directives.

## Testing

No repo-wide test runner. Layers:

- Product `tests/` — basic validation (e.g. `help.test.yml`).
- `helm-tests/smoke-tests/` — fast sanity checks. `ci_scripts/run_helm_smoke.sh`.
- `helm-tests/integration-tests/` — multi-product topologies.
  `ci_scripts/run_helm_integration.sh`. Matrix is driven by
  `helm-tests/integration-tests/integration-tests.json`
  (`tests[].variations[].products[]` with `productName`, `version`, `shim`, `jvm`).

`ci_scripts/` target CI environments. Verify local prerequisites (Kubernetes context,
Docker daemon) before running the helm runners locally.

The Helm charts themselves live in the separate `ping-helm-charts` repo, not here; this
repo only holds the tests that exercise them.

## Review focus

Security, supply-chain integrity (image references and pins), and CI stability. Call out
required environment variables or missing defaults that could break pipelines.
