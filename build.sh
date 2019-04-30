#!/usr/bin/env sh
${VERBOSE} && set -x

c="ping"
p="${c}identity"

#
# Usage printing function
#
usage ()
{
cat <<END_USAGE
Usage: build.sh {options}
    where {options} include:

    -p, --product
        The name of the product for which to build a docker image
    -o, --os
        the name of the operating system for which to build a docker image
    -v, --version
        the version of the product for which to build a docker image
        this setting overrides the versions in the version file of the target product
    --dry-run
        does everything except actually call the docker command and prints it instead
    --help
        Display general usage information
END_USAGE
exit 99
}


buildAndTag ()
{
    product=${1}
    shift
    tag=${1}
    shift
    image=${p}/${c}${product}:${tag}
    ${dryRun} docker image rm ${image} > /dev/null 2>/dev/null
    ${dryRun} docker build --no-cache --rm $* -t ${image} ${c}${product}
    return ${?}
}


productsToBuild="federate access datasync directory"
OSesToBuild="alpine centos ubuntu"
#
# Parse the provided arguments, if any
#
while ! test -z "${1}" ; do
    case "${1}" in
        -o|--os)
            shift
            if test -z "${1}" ; then
                echo "You must provide an OS"
                usage
            fi
            OSesToBuild="${1}"
            ;;

        -p|--product)
            shift
            if test -z "${1}" ; then
                echo "You must provide a product to build"
                usage
            fi
            productsToBuild="${1}"
            ;;

        -v|--version)
            shift
            if test -z "${1}" ; then
                echo "You must provide a version to build"
                usage
            fi
            versionsToBuild="${1}"
            ;;
        
        --dry-run)
            dryRun="echo"
            ;;

        
        --help)
            usage
            ;;
        *)
            echo "Unrecognized option"
            usage
            ;;
    esac
    shift
done


for product in common datacommon ; do
    buildAndTag ${product} latest
    if test ${?} -ne 0 ; then
        echo "*** BUILD BREAK ***"
        echo "${image}"
        exit 75
    fi
done

for shim in ${OSesToBuild} ; do
    # docker image rm -f ${p}/${c}base
    buildAndTag base ${shim} --build-arg SHIM=${shim}
    if test ${?} -ne 0 ; then
        echo "*** BUILD BREAK ***"
        echo "${image}"
        exit 76
    fi

    for product in ${productsToBuild} ; do
        if ! test -f "${c}${product}/versions" ; then
            buildAndTag ${product} edge --build-arg SHIM=${shim}
            if test ${?} -ne 0 ; then
                echo "*** BUILD BREAK ***"
                echo "${image}"
                exit 77
            fi
        else
            firstImage=true
            if test -z "${versionsToBuild}" ; then
                versionsToBuild=$( cat ${c}${product}/versions | grep -v '^#' )
            fi
            for VERSION in ${versionsToBuild} ; do
                buildAndTag ${product} ${VERSION}-${shim}-edge --build-arg VERSION=${VERSION}  --build-arg SHIM=${shim}
                if test ${?} -ne 0 ; then
                    echo "*** BUILD BREAK ***"
                    echo "${image}"
                    exit 78
                fi
                if ${firstImage} && test "${shim}" = "alpine" ; then
                    ${dryRun} docker tag ${p}/${c}${product}:${VERSION}-${shim}-edge ${p}/${c}${product}:edge
                    firstImage=false
                fi
            done
        fi
    done
done