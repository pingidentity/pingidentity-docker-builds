#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

usage() {
    echo "${*}"
    cat << END
    usage: $(basename "${0}") <product> <sourceTag> <destinationRegion> [destinationTag]
        publishes a build to another ECR

        if destinationRegion is not provided, default to us-east-1

        if destinationTag is not provided, defaults to the value of sourceTag

END
    exit 1
}

die() {
    _exitCode=${1}
    shift
    echo "${*}"
    exit "${_exitCode}"
}

test "${1}" = "--help" && usage
test -n "${1}" || usage "missing product"
_product="${1}"
test -n "${2}" || usage "missing source tag"
_srcTag="${2}"
_dstRegion="${3:-us-east-1}"
_dstTag="${4:-${2}}"

type saml2aws || die 2 "saml2aws must be installed"
saml2aws login

test -n "${AWS_ACCOUNT}" || die 4 "AWS_ACCOUNT variable must be set in your env"

type aws || die 3 "aws cli must be installed"
export _srcRegion="us-west-2"
aws ecr get-login-password --region "${_srcRegion}" | docker login --username AWS --password-stdin "${AWS_ACCOUNT}.dkr.ecr.${_srcRegion}.amazonaws.com"
aws ecr get-login-password --region "${_dstRegion}" | docker login --username AWS --password-stdin "${AWS_ACCOUNT}.dkr.ecr.${_dstRegion}.amazonaws.com"

_srcImg="${AWS_ACCOUNT}.dkr.ecr.${_srcRegion}.amazonaws.com/snapshot-builds/${_product}:${_srcTag}"
_dstImg="${AWS_ACCOUNT}.dkr.ecr.${_dstRegion}.amazonaws.com/${_product}:${_dstTag}"
docker pull "${_srcImg}"
docker tag "${_srcImg}" "${_dstImg}"
docker push "${_dstImg}"
docker rmi -f "${_srcImg}" "${_dstImg}"
