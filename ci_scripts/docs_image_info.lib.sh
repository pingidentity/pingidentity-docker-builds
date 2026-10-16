#!/usr/bin/env bash
# shellcheck shell=bash
# Copyright © 2026 Ping Identity Corporation

#
# Ping Identity DevOps - CI scripts
#
# Per-image hand content for deploy_docs.sh (PDI-2517).
#
# Sourced by deploy_docs.sh: IMG_* are set here and consumed there (SC2034
# false positives); IMG_RELATED bodies are single-quoted AsciiDoc with
# backticks — intentional, no expansion wanted (SC2016 info).
#
# shellcheck disable=SC2034,SC2016
#
# deploy_docs.sh generates the whole docker-images/<image>/README.adoc from
# the image Dockerfile (env table, ports, #- doc sections, hooks). The fields
# below are the docs-team prose that has no Dockerfile source:
#
#   IMG_DESCRIPTION : :description: attribute of the generated page
#   IMG_INTRO_PROSE : intro paragraph under the page title
#   IMG_RELATED     : "Related Docker Images" section body (multi-line);
#                     empty = the page has no such section
#
# Seeded from the hand-maintained portal pages (docs-devops-getting-started,
# branch align-docker-images, merged 2026-10-09) after that branch normalized
# all pages onto one shape. Everything structural (anchors, heading levels,
# table shape, footer) is emitted by deploy_docs.sh itself, not per-image —
# no per-image formatting exceptions.
#
# Keep in sync with the Dockerfile #- "Related Docker Images" blocks: this map
# wins at generation time; the Dockerfile blocks stay for build-time readers.

docs_image_info() {
    _img="${1}"
    IMG_DESCRIPTION=""
    IMG_INTRO_PROSE=""
    IMG_RELATED=""

    case "${_img}" in
        pingaccess)
            IMG_DESCRIPTION="Reference environment variables, ports, and run commands for the pingaccess Docker image that runs PingAccess admin and engine nodes"
            IMG_INTRO_PROSE="This docker image includes the Ping Identity PingAccess product binaries and associated hook scripts to create and run both PingAccess Admin and Engine nodes."
            IMG_RELATED='* xref:ROOT:docker-images/pingbase/README.adoc[`pingidentity/pingbase-java`] - Parent Image'
            ;;
        pingfederate)
            IMG_DESCRIPTION="Reference environment variables, ports, and run commands for the pingfederate Docker image that runs PingFederate admin and engine nodes"
            IMG_INTRO_PROSE="This docker image includes the Ping Identity PingFederate product binaries and associated hook scripts to create and run both PingFederate Admin and Engine nodes."
            IMG_RELATED='* xref:ROOT:docker-images/pingbase/README.adoc[`pingidentity/pingbase-java`] - Parent Image'
            ;;
        pingdirectory)
            IMG_DESCRIPTION="Reference environment variables, ports, and run commands for the pingdirectory Docker image that runs a PingDirectory instance"
            IMG_INTRO_PROSE="This docker image includes the Ping Identity PingDirectory product binaries and associated hook scripts to create and run a PingDirectory instance or instances."
            IMG_RELATED='* xref:ROOT:docker-images/pingbase/README.adoc[`pingidentity/pingbase-java`] - Parent Image'
            ;;
        pingdatasync)
            IMG_DESCRIPTION="Reference environment variables, ports, and run commands for the pingdatasync Docker image that runs a PingDataSync instance"
            IMG_INTRO_PROSE="This docker image includes the Ping Identity PingDataSync product binaries and associated hook scripts to create and run a PingDataSync instance."
            IMG_RELATED='* xref:ROOT:docker-images/pingbase/README.adoc[`pingidentity/pingbase-java`] - Parent Image'
            ;;
        pingdirectoryproxy)
            IMG_DESCRIPTION="Reference environment variables, ports, and run commands for the pingdirectoryproxy Docker image that runs a PingDirectoryProxy instance"
            IMG_INTRO_PROSE="This docker image includes the Ping Identity PingDirectoryProxy product binaries and associated hook scripts to create and run a PingDirectoryProxy instance or instances."
            IMG_RELATED='* xref:ROOT:docker-images/pingbase/README.adoc[`pingidentity/pingbase-java`] - Parent Image'
            ;;
        pingauthorize)
            IMG_DESCRIPTION="Reference environment variables, ports, and run commands for the pingauthorize Docker image that runs a PingAuthorize instance"
            IMG_INTRO_PROSE="This docker image includes the Ping Identity PingAuthorize product binaries and associated hook scripts to create and run a PingAuthorize instance or instances."
            IMG_RELATED='* xref:ROOT:docker-images/pingbase/README.adoc[`pingidentity/pingbase-java`] - Parent Image'
            ;;
        pingauthorizepap)
            IMG_DESCRIPTION="Reference environment variables, ports, and run commands for the pingauthorizepap Docker image that runs the PingAuthorize Policy Editor"
            IMG_INTRO_PROSE="This docker image includes the Ping Identity PingAuthorize Policy Editor product binaries and associated hook scripts to create and run a PingAuthorize Policy Editor instance."
            IMG_RELATED='* xref:ROOT:docker-images/pingbase/README.adoc[`pingidentity/pingbase-java`] - Parent Image'
            ;;
        pingcentral)
            IMG_DESCRIPTION="Reference environment variables, ports, and run commands for the pingcentral Docker image that runs PingCentral"
            IMG_INTRO_PROSE="This docker image includes the Ping Identity PingCentral product binaries and associated hook scripts to create and run PingCentral in a container."
            IMG_RELATED='* xref:ROOT:docker-images/pingbase/README.adoc[`pingidentity/pingbase-java`] - Parent Image'
            ;;
        pingdelegator)
            IMG_DESCRIPTION="Reference environment variables and run commands for the pingdelegator Docker image, an NGINX-hosted app for administering PingDirectory users and groups"
            IMG_INTRO_PROSE="This docker image provides an NGINX instance with PingDelegator that can be used in administering PingDirectory Users/Groups."
            IMG_RELATED='* xref:ROOT:docker-images/pingbase/README.adoc[`pingidentity/pingbase`] - Parent Image'
            ;;
        pingtoolkit)
            IMG_DESCRIPTION="Reference environment variables for the pingtoolkit Docker image, used as an init or sidecar container to run server-profile scripts"
            IMG_INTRO_PROSE="This docker image includes the Ping Identity PingToolkit and associated hook scripts to create a container that can pull in a SERVER_PROFILE run scripts.  The typical use case of this image would be an init container or a pod/container to perform tasks aside a running set of pods/containers."
            IMG_RELATED='* xref:ROOT:docker-images/pingbase/README.adoc[`pingidentity/pingbase-java`] - Parent Image'
            ;;
        pingdataconsole)
            IMG_DESCRIPTION="Reference environment variables, ports, and run commands for the pingdataconsole Docker image that serves the PingDataConsole administration UI"
            IMG_INTRO_PROSE="This docker image provides the PingDataConsole administration UI, deployed on Tomcat within the image, for configuration of the PingData products."
            IMG_RELATED='* xref:ROOT:docker-images/pingbase/README.adoc[`pingidentity/pingbase-java`] - Parent Image'
            ;;
        ldap-sdk-tools)
            IMG_DESCRIPTION="Reference environment variables and usage for the ldap-sdk-tools Docker image, which bundles LDAP SDK command-line tools for use against PingDirectory"
            IMG_INTRO_PROSE="This docker image provides LDAP Client SDK command-line tools for use against PingDirectory and other directory servers."
            IMG_RELATED='* xref:ROOT:docker-images/pingbase/README.adoc[`pingidentity/pingbase-java`] - Parent Image'
            ;;
        apache-jmeter)
            IMG_DESCRIPTION="Reference environment variables for the apache-jmeter Docker image used to run Apache JMeter load tests against Ping Identity products"
            IMG_INTRO_PROSE="This docker image provides an alpine image with the Apache JMeter load testing tool for use against Ping Identity product instances."
            IMG_RELATED='* xref:ROOT:docker-images/pingbase/README.adoc[`pingidentity/pingbase-java`] - Parent Image'
            ;;
        *)
            echo_red "ERROR: No docs image info for '${_img}'. Add an entry to ci_scripts/docs_image_info.lib.sh."
            return 1
            ;;
    esac
}
