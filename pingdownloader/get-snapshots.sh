#!/usr/bin/env sh
test "${VERBOSE}" = "true" && set -x

TARGET_DIR="/tmp"
TARGET_FILE="${TARGET_DIR}/product.zip"
TARGET_SIGNATURE=${TARGET_FILE}.sig

_curl() {
    curl \
        --get \
        --silent \
        --insecure \
        --show-error \
        --location \
        --connect-timeout 2 \
        --retry 6 \
        --retry-max-time 30 \
        --retry-connrefused \
        --retry-delay 3 \
        "${@}"
    return ${?}
}

_curlSafe() {
    _httpResultCode=$(_curl --write-out '%{http_code}' "${@}")
    test "${_httpResultCode}" = "200"
    return ${?}
}

_curlSafeFile() {
    _file=${1}
    shift
    _curlSafe --output "${_file}" "${@}"
    return ${?}
}

_getURLForProduct() {
    case "${1}" in
        symphonic-pap-packaged)
            _url="${snapshot_url}/com/pingidentity/pd/governance/${1}"
            ;;
        directory | proxy | sync | broker)
            _url="${snapshot_url}/com/unboundid/product/ds/${1}"
            ;;
        pingfederate | pingdelegator)
            _url="${snapshot_url}"
            ;;
        pingcentral)
            _url="${snapshot_url}/pass/pass-common"
            ;;
        pingaccess)
            _url="${snapshot_url}/products/pingaccess"
            ;;
        *)
            _url=""
            ;;
    esac
    echo "${_url}"
}

_getLatestSnapshotVersionForProduct() {
    case "${1}" in
        pingfederate)
            _curl "$(_getURLForProduct "${1}")/artifact/pf-server/HuronPeak/assembly/base/pom.xml" | sed -e 's/xmlns=".*"//g' | xmllint --xpath 'string(/project/version)' -
            ;;
        pingaccess | pingcentral)
            _curl "$(_getURLForProduct "${1}")/maven-metadata.xml" | sed -e 's/xmlns=".*"//g' | xmllint --xpath 'string(/metadata/versioning/latest)' -
            ;;
        pingdelegator)
            _curl "$(_getURLForProduct "${1}")/maven-metadata.xml" | xmllint --xpath 'string(/metadata/versioning/snapshotVersions/snapshotVersion/value)' -
            ;;
        *)
            _curl "$(_getURLForProduct "${1}")/maven-metadata.xml" | xmllint --xpath 'string(/metadata/versioning/latest)' -
            ;;
    esac
    return ${?}
}

_getLatestSnapshotIDForProductVersion() {
    case "${1}" in
        pingfederate)
            _curl "$(_getURLForProduct "${1}")/buildNumber"
            ;;
        pingaccess | pingcentral)
            _curl "$(_getURLForProduct "${1}")/${2}/maven-metadata.xml" | sed -e 's/xmlns=".*"//g' | xmllint --xpath 'concat(string(/metadata/versioning/snapshot/timestamp),"-",string(/metadata/versioning/snapshot/buildNumber))' -
            ;;
        pingdelegator)
            _curl "$(_getURLForProduct "${1}")/maven-metadata.xml" | xmllint --xpath 'string(/metadata/versioning/snapshotVersions/snapshotVersion/classifier)' -
            ;;
        *)
            _curl "$(_getURLForProduct "${1}")/${2}/maven-metadata.xml" | xmllint --xpath 'string(//snapshotVersion[extension="zip"]/value)' -
            ;;
    esac
    return ${?}
}

_getLatestSnapshotImageForProductVersionID() {
    case "${1}" in
        pingcentral)
            _curlSafeFile ${TARGET_FILE} -H "PRIVATE-TOKEN: ${PING_IDENTITY_GITLAB_TOKEN}" "https://${INTERNAL_GITLAB_URL}/api/v4/projects/2990/jobs/artifacts/master/raw/distribution/target/ping-central-${2}.zip?job=verify-master-job"
            ;;
        pingfederate)
            _curlSafeFile "${TARGET_FILE}" "$(_getURLForProduct "${1}")/artifact/pf-server/HuronPeak/assembly/base/target/${1}-base-${2}.zip"
            ;;
        pingaccess)
            _curlSafeFile "${TARGET_FILE}" "$(_getURLForProduct "${1}")/${2}/${1}-${2%-SNAPSHOT}-${3}.zip"
            ;;
        pingdelegator)
            _curlSafeFile "${TARGET_FILE}" "$(_getURLForProduct "${1}")/pingdirectory-delegator-${2}-${3}.zip"
            ;;
        *)
            _curlSafeFile "${TARGET_FILE}" "$(_getURLForProduct "${1}")/${2}/${1}-${3}-image.zip"
            ;;
    esac
    return ${?}
}

_getLatestSnapshotImageSignatureForProductVersionID() {
    case "${1}" in
        # bad students who do not sign their work
        pingfederate | pingcentral | pingaccess)
            sha1sum /tmp/product.zip | awk '{print $1}' > "${TARGET_SIGNATURE}"
            ;;
        pingdelegator)
            _curlSafeFile "${TARGET_SIGNATURE}" "$(_getURLForProduct "${1}")/pingdirectory-delegator-${2}-${3}.zip.sha1"
            ;;
        *)
            _curlSafeFile "${TARGET_SIGNATURE}" "$(_getURLForProduct "${1}")/${2}/${1}-${3}-image.zip.sha1"
            ;;
    esac
    return ${?}
}

_sha1SignaturesDoMatch() {
    _computedSignature=$(sha1sum "${TARGET_FILE}" | awk '{print $1}')
    _downloadedSignature=$(cat "${TARGET_SIGNATURE}")
    if test -n "${_computedSignature}" && test -n "${_downloadedSignature}" && test "${_computedSignature}" = "${_downloadedSignature}"; then
        return 0
    else
        rm -f "${TARGET_FILE}" "${TARGET_SIGNATURE}"
        return 1
    fi
}

case "${1}" in
    pingdirectory)
        _product=directory
        ;;
    pingdirectoryproxy)
        _product=proxy
        ;;
    pingdatasync)
        _product=sync
        ;;
    pingauthorize)
        _product=broker
        ;;
    pingauthorizepap)
        _product=symphonic-pap-packaged
        ;;
    delegator)
        _product=pingdelegator
        ;;
    pingfederate | pingaccess | pingcentral)
        _product="${1}"
        ;;
    *)
        echo unsupported product
        exit 4
        ;;
esac

snapshot_url="${2}"

if test -n "${_product}"; then
    _version=$(_getLatestSnapshotVersionForProduct "${_product}")
    _id=$(_getLatestSnapshotIDForProductVersion "${_product}" "${_version}")
    if _getLatestSnapshotImageForProductVersionID "${_product}" "${_version}" "${_id}"; then
        if _getLatestSnapshotImageSignatureForProductVersionID "${_product}" "${_version}" "${_id}"; then
            _sha1SignaturesDoMatch
            exit ${?}
        else
            exit 2
        fi
    else
        exit 3
    fi
fi
exit 0
