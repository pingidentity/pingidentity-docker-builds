# AI Tooling Instructions

This repository contains Docker build contexts, Helm integration tests, and CI scripts for Ping Identity products. Follow these guidelines when making changes.

## Repository map
- `ci_scripts/`: CI helpers, integration test runner, and post-render scripts (bash).
- `helm-tests/`: integration test suites and values files.
- `ping*`, `ldap-sdk-tools/`, `apache-jmeter/`, `pingtoolkit/`: product image build contexts and related assets.

## Change safety
- Preserve behavior by default. Do not alter ports, image tags, registries, or security contexts unless explicitly requested.
- Do not introduce new runtime dependencies in CI scripts (e.g., language runtimes or OS packages) without approval.
- Avoid committing secrets. Use existing environment variables or documented inputs.

## Shell script conventions
- Scripts are bash; keep `set -euo pipefail` semantics intact where present.
- Prefer simple, portable tools already used in the repo (bash, sed, awk, jq, perl).
- Keep stdout/stderr behavior stable for CI logs; add output only when necessary.
- Use ci_scripts/shfmt.sh and ci_scripts/shellcheck.sh to format and lint shell scripts before committing

## Testing and validation
- There is no single repo-wide test runner. If validation is required, use the most relevant script in `ci_scripts/` or the product-specific README.
- For Helm integration, the entry point is typically `ci_scripts/run_helm_integration.sh`.

## Review focus
- Prioritize security, supply-chain integrity (image references), and CI stability.
- Call out any required environment variables or missing defaults that could break pipelines.

## Docker Guidelines
- Minimize image layers; combine `RUN` commands where logical.
- Clean up package manager caches (apk/apt) within the same layer to reduce image size.
- Preserve existing `USER` directives to ensure container security standards.
- Pin base images (shims) to specific tags/digests; avoid `latest`.

## Version Management
- `versions.json` drives the build matrix. Validate JSON syntax strictly before committing.
- When updating versions, check if the global `latest` key needs updating.
- Ensure new entries match the schema of existing entries (shims, JVMs, registry flags).

## Local Development
- Note that `ci_scripts/` are designed for CI environments. verify local prerequisites (e.g. Kubernetes context) before running `run_helm_integration.sh`.