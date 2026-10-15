# Ping Identity DevOps - Docker Builds

Provides all components to build out the Ping Identity DevOps Docker Images for your own development, testing and deployments.

## Documentation

* The complete collection of documentation for Ping Identity’s DevOps GitHub repositories is located on [Git Pages](https://devops.pingidentity.com/)

## Docker images

* A complete listing of Ping Identity's public images used in these examples is available at [Docker Hub](https://hub.docker.com/u/pingidentity/)

## Building all products locally

There is no build-all script; run `ci_scripts/build_product.sh --product <product>` for
each product directory. Versions, shims, and JVMs resolve from each product's
`versions.json`:

```sh
for p in apache-jmeter ldap-sdk-tools pingaccess pingauthorize pingauthorizepap \
         pingcentral pingdataconsole pingdatasync pingdelegator pingdirectory \
         pingdirectoryproxy pingfederate pingtoolkit; do
    ci_scripts/build_product.sh --product "$p" || break
done
```

`ci_scripts/build_custom_image.sh` builds a single product at a fixed
product/JVM/shim/sprint combination.

## Base images

Every product image is a thin final stage over a Ping-provided base image —
`pingbase-java` for JVM products, `pingbase` for non-JVM (see
[`pingidentity/pingbase-java`](https://hub.docker.com/r/pingidentity/pingbase-java)).
The shared runtime scaffold those images run on lives in `runtime/` in this
repository and is COPY'd into each product build from the root context.

## Troubleshooting

If you experience issues with this project, please see details on contributing feedback at [Contributing](CONTRIBUTING.md).
