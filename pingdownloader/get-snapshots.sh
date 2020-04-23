#!/usr/bin/env sh
test -n "${VERBOSE}" && set -x

TARGET_DIR="/tmp"
TARGET_FILE="${TARGET_DIR}/product.zip"
TARGET_SIGNATURE=${TARGET_FILE}.sig

_curl ()
{
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

_curlSafe ()
{
    _httpResultCode=$( _curl --write-out '%{http_code}' "${@}" )
    test ${_httpResultCode} -eq 200
    return ${?}
}

 _curlSafeFile ()
 {
    _file=${1}
    shift
    _curlSafe --output "${_file}" "${@}"
    return ${?}
 }

_getURLForProduct ()
{
    _baseURL="http://nexus-qa.austin-eng.ping-eng.com:8081/nexus/service/local/repositories/snapshots/content"
    case "${1}" in
        symphonic-pap-packaged)
            _basePath="com/pingidentity/pd/governance"
            _url="${_baseURL:+${_baseURL}/${_basePath}/${1}}"
            ;;
        directory|proxy|sync|broker) 
            _basePath="com/unboundid/product/ds"
            _url="${_baseURL:+${_baseURL}/${_basePath}/${1}}"
            ;;
        pingfederate)
            _url="https://bld-fed01.corp.pingidentity.com/job/PingFederate_Mainline/lastSuccessfulBuild"
            ;;
        pingcentral)
            _url="https://gitlab.corp.pingidentity.com/api/v4/projects/2990/jobs/artifacts/master/raw/distribution/target"
            ;;
        pingaccess)
            _url="https://art01.corp.pingidentity.com/artifactory/repo/com/pingidentity/products/pingaccess"
            ;;
        *)
            _url=""
            ;;
    esac
    echo "${_url}"
}

_getLatestSnapshotVersionForProduct ()
{
    case "${1}" in
        pingcentral)
            echo "1.4.0-SNAPSHOT"
            ;;
        pingfederate)
            _curl "$( _getURLForProduct ${1} )/artifact/pf-server/HuronPeak/assembly/pom.xml" | sed -e 's/xmlns=".*"//g' | xmllint --xpath 'string(/project/version)' -
            ;;
        pingaccess)
            _curl "$( _getURLForProduct ${1} )/maven-metadata.xml" | sed -e 's/xmlns=".*"//g' | xmllint --xpath 'string(/metadata/versioning/latest)' -
            ;;
        *)
            _curl "$( _getURLForProduct ${1} )/maven-metadata.xml" | xmllint --xpath 'string(/metadata/versioning/latest)' -
        ;;
    esac
    return ${?}
}

_getLatestSnapshotIDForProductVersion ()
{
    case "${1}" in
        pingcentral)
            date '+%Y%m%d'
            ;;
        pingfederate)
            _curl "$( _getURLForProduct ${1} )/buildNumber" 
            ;;
        pingaccess)
            _curl "$( _getURLForProduct ${1} )/${2}/maven-metadata.xml" | sed -e 's/xmlns=".*"//g' |xmllint --xpath 'concat(string(/metadata/versioning/snapshot/timestamp),"-",string(/metadata/versioning/snapshot/buildNumber))' -
            ;;
        *)
            _curl "$( _getURLForProduct ${1} )/${2}/maven-metadata.xml" | xmllint --xpath 'string(//snapshotVersion[extension="zip"]/value)' -
            ;;
    esac
    return ${?}
}

_getLatestSnapshotImageForProductVersionID ()
{
    case "${1}" in
        pingcentral)
            _curlSafeFile ${TARGET_FILE} -H "PRIVATE-TOKEN: ${PING_IDENTITY_GITLAB_TOKEN}" "$( _getURLForProduct ${1} )/ping-central-${2}.zip?job=deploy-job"
            ;;
        pingfederate)
            _curlSafeFile "${TARGET_FILE}" "$( _getURLForProduct ${1} )/artifact/pf-server/HuronPeak/assembly/target/${1}-${2}-${3}.zip"
            ;;
        pingaccess)
            _curlSafeFile "${TARGET_FILE}" "$( _getURLForProduct ${1} )/${2}/${1}-${2%-SNAPSHOT}-${3}.zip"
            ;;
        *)
            _curlSafeFile "${TARGET_FILE}" "$( _getURLForProduct ${1} )/${2}/${1}-${3}-image.zip"
            ;;
    esac
    return ${?}
}

_getLatestSnapshotImageSignatureForProductVersionID ()
{
    case "${1}" in
        # bad students who do not sign their work
        pingfederate|pingcentral|pingaccess)
            sha1sum /tmp/product.zip | awk '{print $1}' > "${TARGET_SIGNATURE}"
            ;;
        *)
            _curlSafeFile "${TARGET_SIGNATURE}" "$( _getURLForProduct ${1} )/${2}/${1}-${3}-image.zip.sha1"
            ;;
    esac
    return ${?}
}

_sha1SignaturesDoMatch ()
{
    _computedSignature=$( sha1sum "${TARGET_FILE}"|awk '{print $1}' )
    _downloadedSignature=$( cat "${TARGET_SIGNATURE}" )
    if test -n "${_computedSignature}" && test -n "${_downloadedSignature}" && test "${_computedSignature}" = "${_downloadedSignature}" ;
    then
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
    pingdatagovernance) 
        _product=broker
        ;;
    pingdatagovernancepap)
        _product=symphonic-pap-packaged
        ;;
    pingfederate|pingaccess|pingcentral)
        _product="${1}"
        ;;
    *)
        echo unsupported product
        exit 4
        ;;
esac

if test -n "${_product}" ;
then
    _version=$( _getLatestSnapshotVersionForProduct ${_product} )
    _id=$( _getLatestSnapshotIDForProductVersion ${_product} ${_version} )
    if _getLatestSnapshotImageForProductVersionID ${_product} ${_version} ${_id} ;
    then
        if _getLatestSnapshotImageSignatureForProductVersionID ${_product} ${_version} ${_id} ;
        then
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