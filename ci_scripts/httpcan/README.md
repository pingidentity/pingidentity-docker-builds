# httpcan

## Overview

Httpcan is a replacement for the <https://httpbin.org> service.  Due to stability issues of that site, and to remove external dependencies, this target endpoint is now deployed in-cluster. To do so, this Helm post-renderer modifies Kubernetes manifests to include the service and endpoint.

The tests were modified slightly to use httpcan instead of httpbin, including using all lowercase headers sending and receiving.

## Image Source

**Image:** docker.corp.pingidentity.com:5300/httpcan:0.5.3

**Repository:** <https://gitlab.corp.pingidentity.com/devops-program/httpcan>

This repository contains the source code and Dockerfile for building the httpcan image.  It was forked from <https://github.com/seedvector/httpcan> via Github and the internal Gitlab remote added.  The only changes from the main branch of the original repository was to add startup and liveness scripts to conform to Ping Identity container standards, and to allow healthchecks to function properly in Kubernetes.  There is a script for building and pushing the image in this repository.

## Usage

This tool is used as a Helm post-renderer in the CI pipeline. See [post-renderer.sh](post-renderer.sh) for implementation details.

### Integration

If any integration tests require httpcan, ensure that the Helm chart values for the test include the following to enable the post-renderer.  You can see `helm-tests/integration-tests/pa-pf-pd-fips/pa-pf-pd-fips.yaml` for an example.  All existing tests using httpcan already have this configured.

```yaml
httpcan:
  enabled: true
  containerPort: 8080
  service:
    name: httpcan
    port: 80
    targetPort: 8080
```

## Related Scripts

- [post-renderer.sh](post-renderer.sh) - Helm post-renderer implementation
- [run_helm_integration.sh](../run_helm_integration.sh) - Main integration test runner
