#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#
test "${VERBOSE}" = "true" && set -x

# Usage printing function
usage() {
    test -n "${*}" && echo "${*}"
    cat << END_USAGE
Usage: ${0} {options}
    where {options} include:
    -p, --product
        The desired product name to download product bits for.
    -v, --version
        The desired version of the specified product.
    -o, --output
        The output file name for the downloaded product bits placed in /tmp.
    --help
        Display general usage information.
END_USAGE
    exit 99
}

# Read in product and version from command line options.
while ! test -z "${1}"; do
    case "${1}" in
        -p | --product)
            test -z "${2}" && usage "You must provide a product name with option --product."
            shift
            product_name="${1}"
            ;;
        -v | --version)
            test -z "${2}" && usage "You must provide a product version with option --version."
            shift
            product_version="${1}"
            ;;
        -o | --output)
            test -z "${2}" && usage "You must provide a output file name with option --output."
            shift
            output_file="${1}"
            ;;
        --help)
            usage
            ;;
        *)
            usage "Unrecognized option: ${1}"
            ;;
    esac
    shift
done

# Require product name and product version to be specified.
test -z "${product_name}" && usage "You must specify a product name to download bits for. Examples of valid product names include pingfederate or pingcentral."
test -z "${product_version}" && usage "You must specify a product version to download bits for ${product_name}."
output_file=${output_file:-"product.zip"}
pingdata_products="pingauthorize pingauthorizepap pingdataconsole pingdatasync pingdelegator pingdirectory pingdirectoryproxy"

# Test if there is a local ${output_file} file in tmp already. If so, exit this script early.
if test -f "/tmp/${output_file}"; then
    echo "Found local ${output_file} file. Skipping product bits download in favor of file system override..." && exit 0
fi

# Specify bits_download_url based on the product_name specified.
case "${product_name}" in
    apache-jmeter)
        bits_file_name="${product_name}-${product_version}.zip"
        bits_download_url="https://archive.apache.org/dist/jmeter/binaries/${bits_file_name}"
        ;;
    apache-tomcat)
        bits_file_name="${product_name}-${product_version}.zip"
        bits_download_url="https://archive.apache.org/dist/tomcat/tomcat-9/v${product_version}/bin/${bits_file_name}"
        ;;
    ldap-sdk-tools)
        bits_file_name="unboundid-ldapsdk-${product_version}.zip"
        bits_download_url="https://github.com/pingidentity/ldapsdk/releases/download/${product_version}/${bits_file_name}"
        ;;
    pingaccess)
        if test -n "${SNAPSHOT_URL}"; then
            # Get snapshot ID from maven-metadata.xml
            product_version_metadata_url="${SNAPSHOT_URL}/products/${product_name}/${product_version}/maven-metadata.xml"
            product_snapshot_id="$(wget -q -O - "${product_version_metadata_url}" | sed -e 's/xmlns=".*"//g' | xmllint --xpath 'concat(string(/metadata/versioning/snapshot/timestamp),"-",string(/metadata/versioning/snapshot/buildNumber))' -)"

            bits_file_name="${product_name}-${product_version%-SNAPSHOT}-${product_snapshot_id}.zip"
            bits_download_url="${SNAPSHOT_URL}/products/${product_name}/${product_version}/${bits_file_name}"
        else
            bits_file_name="${product_name}-${product_version}.zip"
            bits_download_url="${ARTIFACTORY_URL}/libs-releases-local/com/pingidentity/products/${product_name}/${product_version}/${bits_file_name}"
        fi
        ;;
    pingauthorize)
        if test -n "${SNAPSHOT_URL}"; then
            # Get snapshot ID from maven-metadata.xml
            product_version_metadata_url="${SNAPSHOT_URL}/com/unboundid/product/ds/broker/${product_version}/maven-metadata.xml"
            product_snapshot_id="$(wget -q -O - "${product_version_metadata_url}" | xmllint --xpath 'string(//snapshotVersion[extension="zip"]/value)' -)"

            bits_file_name="broker-${product_snapshot_id}-docker-image.zip"
            bits_download_url="${SNAPSHOT_URL}/com/unboundid/product/ds/broker/${product_version}/${bits_file_name}"
        else
            bits_file_name="PingAuthorize-${product_version}.zip"
            # Remove `-EA` or similar from PingData zip file names
            bits_file_name="$(echo "${bits_file_name}" | sed -e "s/-[^0-9\.]*\.zip/\.zip/")"
            bits_download_url="${ARTIFACTORY_URL}/installs/com/pingidentity/${product_name}/${product_name}/${product_version}/docker/${bits_file_name}"
        fi
        ;;
    pingauthorizepap)
        if test -n "${SNAPSHOT_URL}"; then
            # Get snapshot ID from maven-metadata.xml
            product_version_metadata_url="${SNAPSHOT_URL}/com/pingidentity/pd/governance/symphonic-pap-packaged/${product_version}/maven-metadata.xml"
            product_snapshot_id="$(wget -q -O - "${product_version_metadata_url}" | xmllint --xpath 'string(//snapshotVersion[extension="zip"]/value)' -)"

            bits_file_name="symphonic-pap-packaged-${product_snapshot_id}-image.zip"
            bits_download_url="${SNAPSHOT_URL}/com/pingidentity/pd/governance/symphonic-pap-packaged/${product_version}/${bits_file_name}"
        else
            bits_file_name="PingAuthorize-PAP-${product_version}.zip"
            # Remove `-EA` or similar from PingData zip file names
            bits_file_name="$(echo "${bits_file_name}" | sed -e "s/-[^0-9\.]*\.zip/\.zip/")"
            bits_download_url="${ARTIFACTORY_URL}/installs/com/pingidentity/pingauthorize/pingauthorize_policy_editor/${product_version}/${bits_file_name}"
        fi
        ;;
    pingcentral)
        if test -n "${SNAPSHOT_URL}"; then
            # Get lastSuccessfulBuild filename
            product_version_api_json_url="${SNAPSHOT_URL}/api/json"
            bits_file_name="$(wget -q -O - "${product_version_api_json_url}" | jq -r '.artifacts[] | .fileName')"

            bits_download_url="${SNAPSHOT_URL}/artifact/distribution/target/${bits_file_name}"
        else
            bits_file_name="ping-central-${product_version}.zip"
            bits_download_url="${ARTIFACTORY_URL}/libs-releases-local/com/pingidentity/products/ping-central/${product_version}/${bits_file_name}"
        fi
        ;;
    pingdatasync)
        if test -n "${SNAPSHOT_URL}"; then
            # Get snapshot ID from maven-metadata.xml
            product_version_metadata_url="${SNAPSHOT_URL}/com/unboundid/product/ds/sync/${product_version}/maven-metadata.xml"
            product_snapshot_id="$(wget -q -O - "${product_version_metadata_url}" | xmllint --xpath 'string(//snapshotVersion[extension="zip"]/value)' -)"

            bits_file_name="sync-${product_snapshot_id}-docker-image.zip"
            bits_download_url="${SNAPSHOT_URL}/com/unboundid/product/ds/sync/${product_version}/${bits_file_name}"
        else
            bits_file_name="PingDataSync-${product_version}.zip"
            # Remove `-EA` or similar from PingData zip file names
            bits_file_name="$(echo "${bits_file_name}" | sed -e "s/-[^0-9\.]*\.zip/\.zip/")"
            bits_download_url="${ARTIFACTORY_URL}/installs/com/pingidentity/${product_name}/${product_version}/docker/${bits_file_name}"
        fi
        ;;
    pingdelegator)
        if test -n "${SNAPSHOT_URL}"; then
            # Get snapshot ID from maven-metadata.xml
            product_version_metadata_url="${SNAPSHOT_URL}/maven-metadata.xml"
            product_snapshot_id="$(wget -q -O - "${product_version_metadata_url}" | xmllint --xpath 'string(/metadata/versioning/snapshotVersions/snapshotVersion/classifier)' -)"

            bits_file_name="pingdirectory-delegator-${product_version}-${product_snapshot_id}.zip"
            bits_download_url="${SNAPSHOT_URL}/${bits_file_name}"
        else
            bits_file_name="pingdirectory-delegator-${product_version}.zip"
            bits_download_url="${ARTIFACTORY_URL}/installs/com/pingidentity/pingdirectory_delegated_administration/${product_version}/${bits_file_name}"
        fi
        ;;
    pingdirectory | pingdataconsole)
        if test -n "${SNAPSHOT_URL}"; then
            # Get snapshot ID from maven-metadata.xml
            product_version_metadata_url="${SNAPSHOT_URL}/com/unboundid/product/ds/directory/${product_version}/maven-metadata.xml"
            product_snapshot_id="$(wget -q -O - "${product_version_metadata_url}" | xmllint --xpath 'string(//snapshotVersion[extension="zip"]/value)' -)"

            bits_file_name="directory-${product_snapshot_id}-docker-image.zip"
            bits_download_url="${SNAPSHOT_URL}/com/unboundid/product/ds/directory/${product_version}/${bits_file_name}"
        else
            bits_file_name="PingDirectory-${product_version}.zip"
            # Remove `-EA` or similar from PingData zip file names
            bits_file_name="$(echo "${bits_file_name}" | sed -e "s/-[^0-9\.]*\.zip/\.zip/")"
            # TODO Re-add reduced size docker zip file retrieval here once FEDRAMP images have been updated to PD version 9.0 or newer
            # bits_download_url="${ARTIFACTORY_URL}/installs/com/pingidentity/pingdirectory/${product_version}/docker/${bits_file_name}"
            bits_download_url="${ARTIFACTORY_URL}/installs/com/pingidentity/pingdirectory/${product_version}/${bits_file_name}"
        fi
        ;;
    pingdirectoryproxy)
        if test -n "${SNAPSHOT_URL}"; then
            # Get snapshot ID from maven-metadata.xml
            product_version_metadata_url="${SNAPSHOT_URL}/com/unboundid/product/ds/proxy/${product_version}/maven-metadata.xml"
            product_snapshot_id="$(wget -q -O - "${product_version_metadata_url}" | xmllint --xpath 'string(//snapshotVersion[extension="zip"]/value)' -)"

            bits_file_name="proxy-${product_snapshot_id}-docker-image.zip"
            bits_download_url="${SNAPSHOT_URL}/com/unboundid/product/ds/proxy/${product_version}/${bits_file_name}"
        else
            bits_file_name="PingDirectoryProxy-${product_version}.zip"
            # Remove `-EA` or similar from PingData zip file names
            bits_file_name="$(echo "${bits_file_name}" | sed -e "s/-[^0-9\.]*\.zip/\.zip/")"
            bits_download_url="${ARTIFACTORY_URL}/installs/com/pingidentity/${product_name}/${product_version}/docker/${bits_file_name}"
        fi
        ;;
    pingfederate)
        if test -n "${SNAPSHOT_URL}"; then
            bits_file_name="${product_name}-base-${product_version}.zip"
            bits_download_url="${SNAPSHOT_URL}/artifact/pf-server/HuronPeak/assembly/base/target/${bits_file_name}"
        else
            bits_file_name="${product_name}-${product_version}.zip"
            bits_download_url="${ARTIFACTORY_URL}/libs-releases-local/${product_name}/${product_name}/${product_version}/${bits_file_name}"
        fi
        ;;
    pingintelligence)
        bits_file_name="pi-api-ase-rhel-${product_version}.tar.gz"
        bits_download_url="${ARTIFACTORY_URL}/installs/com/pingidentity/${product_name}/kits/pingintelligence_ase_for_rhel/${product_version}/${bits_file_name}"
        ;;
    tini)
        case "$(uname -m)" in
            x86_64)
                bits_file_name="tini-static-amd64"
                ;;
            aarch64)
                bits_file_name="tini-static-arm64"
                ;;
            *)
                usage "Unrecognized Architecture $(uname -m) for ${product_name} ${product_version}."
                ;;
        esac
        bits_download_url="https://github.com/krallin/tini/releases/download/v${product_version}/${bits_file_name}"
        ;;
    *)
        usage "Unrecognized product name: ${product_name}"
        ;;
esac

# Download the product bits from Artifactory and place them in /tmp.
# Rename product bits file to product.zip for easy un-packaging in Dockerfiles.
# Most common reasons this portion fails on a local run of the script are:
# The user has not provided a local product zip in <product>/tmp directory
# OR The user is not on the Ping Identity internal VPN
# OR The user does not have the ARTIFACTORY_URL defined in their environment.
echo "Retrieving product bits for ${product_name} ${product_version}..."
wget -O "/tmp/${output_file}" "${bits_download_url}"
test $? -ne 0 && echo "Error: Could not retrieve artifact ${bits_file_name} from ${bits_download_url}" && exit 1
echo "Successfully retrieved artifact ${bits_file_name} from ${bits_download_url}."

# Verify product bits using Artifactory's built-in SHA-256 endpoint.
# Only verify with this method if product bits are sourced from Artifactory, as some snapshot bits are not.
if test "${bits_download_url#*"${ARTIFACTORY_URL}"}" != "${bits_download_url}"; then
    echo "Verifying product bits ${bits_file_name} via SHA-256..."
    wget -O "/tmp/${output_file}.sha256" "${bits_download_url}.sha256"
    test $? -ne 0 && echo "Error: Could not retrieve sha256 of artifact ${bits_file_name} from ${bits_download_url}.sha256" && exit 1
    echo "$(cat "/tmp/${output_file}.sha256")  /tmp/${output_file}" | sha256sum -c -s -
    test $? -ne 0 && echo "Error: The SHA-256 check failed for the downloaded artifact ${bits_file_name} from ${bits_download_url}." && exit 1
    rm "/tmp/${output_file}.sha256"
    echo "Successfully verified artifact ${bits_file_name}."

# Verify snapshot bits for PingData
elif test -n "${SNAPSHOT_URL}" && test "${pingdata_products#*"${product_name}"}" != "${pingdata_products}"; then
    echo "Verifying PingData Snapshot bits ${bits_file_name} via SHA-1..."
    wget -O "/tmp/${output_file}.sha1" "${bits_download_url}.sha1"
    test $? -ne 0 && echo "Error: Could not retrieve sha1 of artifact ${bits_file_name} from ${bits_download_url}.sha1" && exit 1
    echo "$(cat "/tmp/${output_file}.sha1")  /tmp/${output_file}" | sha1sum -c -s -
    test $? -ne 0 && echo "Error: The SHA-1 check failed for the downloaded artifact ${bits_file_name} from ${bits_download_url}." && exit 1
    rm "/tmp/${output_file}.sha1"
    echo "Successfully verified artifact ${bits_file_name}."

# Verify apache-jmeter and apache-tomcat product bits
elif test "${product_name}" = "apache-jmeter" || test "${product_name}" = "apache-tomcat"; then
    # Perform a SHA-512 check
    echo "Verifying ${product_name} product bits ${bits_file_name}..."
    wget -O "/tmp/${output_file}.sha512" "${bits_download_url}.sha512"
    test $? -ne 0 && echo "Error: Could not retrieve sha512 of artifact ${bits_file_name} from ${bits_download_url}.sha512" && exit 1
    echo "$(awk 'FNR == 1 {print $1}' "/tmp/${output_file}.sha512")  /tmp/${output_file}" | sha512sum -c -s -
    test $? -ne 0 && echo "Error: The SHA-512 check failed for the artifact ${bits_file_name} from ${bits_download_url}." && exit 1
    rm "/tmp/${output_file}.sha512"

    # Perform a gpg signature verification. GPG keys should be installed in product's Dockerfile.
    command -v gpg > /dev/null
    test $? -ne 0 && echo "Error: Command gpg not found." && exit 1
    gpg --import "/tmp/keys.gpg"
    test $? -ne 0 && echo "Error: Public key import of ${product_name} signing keys failed." && exit 1
    wget -O "/tmp/${output_file}.asc" "${bits_download_url}.asc"
    test $? -ne 0 && echo "Error: Could not retrieve asc of artifact ${bits_file_name} from ${bits_download_url}.asc" && exit 1
    gpg --verify "/tmp/${output_file}.asc" "/tmp/${output_file}"
    test $? -ne 0 && echo "Error: The signature verification failed for the artifact ${bits_file_name} from ${bits_download_url}." && exit 1
    rm -f "/tmp/keys.gpg"
    rm -f "/tmp/${output_file}.asc"

    echo "Successfully verified artifact ${bits_file_name}."

elif test "${product_name}" = "tini"; then
    # Perform a SHA-256 check
    echo "Verifying Tini product bits ${bits_file_name}..."
    wget -O "/tmp/${output_file}.sha256sum" "${bits_download_url}.sha256sum"
    test $? -ne 0 && echo "Error: Could not retrieve sha256 of artifact ${bits_file_name} from ${bits_download_url}.sha256sum" && exit 1
    echo "$(awk 'FNR == 1 {print $1}' "/tmp/${output_file}.sha256sum")  /tmp/${output_file}" | sha256sum -c -s -
    test $? -ne 0 && echo "Error: The SHA-256 check failed for the artifact ${bits_file_name} from ${bits_download_url}." && exit 1
    rm "/tmp/${output_file}.sha256sum"

    # Perform a gpg signature verification. GPG should be installed in pingcommon's Dockerfile.
    command -v gpg > /dev/null
    test $? -ne 0 && echo "Error: Command gpg not found." && exit 1
    gpg --import "/tmp/key.gpg"
    test $? -ne 0 && echo "Error: Public key import of Tini signing key failed." && exit 1
    wget -O "/tmp/${output_file}.asc" "${bits_download_url}.asc"
    test $? -ne 0 && echo "Error: Could not retrieve asc of artifact ${bits_file_name} from ${bits_download_url}.asc" && exit 1
    gpg --verify "/tmp/${output_file}.asc" "/tmp/${output_file}"
    test $? -ne 0 && echo "Error: The signature verification failed for the artifact ${bits_file_name} from ${bits_download_url}." && exit 1
    rm -f "/tmp/key.gpg"
    rm -f "/tmp/${output_file}.asc"

    echo "Successfully verified artifact ${bits_file_name}."

else
    # ldap-sdk-tools does no verification as GitHub does not support a native SHA check unless provided by the
    # repository owners, which we currently do not do.
    # Snapshot PingFederate and Snapshot PingCentral do not generate SHA files for verification.
    echo "Skipping artifact verification..."
fi

echo "Download of product bits for ${product_name} ${product_version} complete."

exit 0
