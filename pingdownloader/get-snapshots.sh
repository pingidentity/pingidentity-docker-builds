#!/usr/bin/env sh
test -n "${VERBOSE}" && set -x

_curl ()
{
    curl \
        --get \
        --silent \
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

_getURLForProduct ()
{
    _baseURL="http://nexus-qa.austin-eng.ping-eng.com:8081/nexus/service/local/repositories/snapshots/content"
    case "${1}" in
        symphonic-pap-packaged)
            _basePath="com/pingidentity/pd/governance"
            ;;
        directory|proxy|sync|broker) 
            _basePath="com/unboundid/product/ds"
            ;;
        *)
            _baseURL=""
            _basePath=""
            ;;
    esac
    echo "${_baseURL:+${_baseURL}/${_basePath}/${1}}"
}

_getLatestSnapshotVersionForProduct ()
{
    _curl $( _getURLForProduct ${1} )/maven-metadata.xml | xmllint --xpath 'string(/metadata/versioning/latest)' -
    return ${?}
}

_getLatestSnapshotIDForProductVersion ()
{
    _curl $( _getURLForProduct ${1} )/${2}/maven-metadata.xml | xmllint --xpath 'string(//snapshotVersion[extension="zip"]/value)' -
    return ${?}
}

_getLatestSnapshotImageForProductVersionID ()
{
    _curl -o /tmp/product.zip $( _getURLForProduct ${1} )/${2}/${1}-${3}-image.zip
}

_getLatestSnapshotImageSignatureForProductVersionID ()
{
    _curl -o /tmp/product.zip.sha1 $( _getURLForProduct ${1} )/${2}/${1}-${3}-image.zip.sha1
}

_sha1SignaturesDoMatch ()
{
    _computedSignature=$( sha1sum /tmp/product.zip|awk '{print $1}' )
    _downloadedSignature=$( cat /tmp/product.zip.sha1 )
    if test -n "${_computedSignature}" && test -n "${_downloadedSignature}" && test "${_computedSignature}" = "${_downloadedSignature}" ;
    then
        return 0
    else
        rm -f /tmp/product.zip /tmp/product.zip.sha1
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
esac

if test -n "${_product}" ;
then
    _version=$( _getLatestSnapshotVersionForProduct ${_product} )
    _id=$( _getLatestSnapshotIDForProductVersion ${_product} ${_version} )
    _getLatestSnapshotImageForProductVersionID ${_product} ${_version} ${_id}
    _getLatestSnapshotImageSignatureForProductVersionID ${_product} ${_version} ${_id}
    _sha1SignaturesDoMatch
    exit ${?}
fi
exit 0