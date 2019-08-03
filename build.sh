#!/usr/bin/env sh 
#
# Ping Identity DevOps
#
test ! -z "${VERBOSE}" && ${VERBOSE} && set -x

c="ping"
p="${c}identity"

red='\033[0;31m'
green='\033[0;32m'
normal=$(tput sgr0)

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
    --use-cache
        use cached layers. useful to avoid re-building unchanged images, notably: pingbase
    --dry-run
        does everything except actually call the docker command and prints it instead
    --help
        Display general usage information
END_USAGE
exit 99
}

#
# Build and Tag a new docker image
#
# Expents arguments:
#  - product (i.e. directory)
#  - version (i.e. 7.3.0.0)
#  - shim    (i.e. alpine)
#  - tag     (i.e. edge)
#
buildAndTag ()
{
    _product="${1}"
    _version="${2}"
    _shim="${3}"
    _tag="${4}"
    _image=${p}/${c}${_product}:${_tag}

    CURRENT_DATE=$( date +"%y%m%d" )
    CURRENT_SHORT_GIT_REV=$( git rev-parse --short=4 HEAD )
    CURRENT_LONG_GIT_REV=$( git rev-parse HEAD )
    IMAGE_VERSION="${c}${_product}-${_shim}-${_version}-${CURRENT_DATE}-${CURRENT_SHORT_GIT_REV}"

    docker image rm "${_image}" > /dev/null 2>/dev/null

    dockerCmd="docker build ${useCache} --build-arg SHIM=${_shim} --build-arg VERSION=${_version} --build-arg IMAGE_VERSION=${IMAGE_VERSION} --build-arg IMAGE_GIT_REV=${CURRENT_LONG_GIT_REV} -t ${_image} ${c}${_product}"

    echo ""
    echo "###########################################################################"
    echo "# Building: $_image"
    echo "#  Command: $dockerCmd"

    if test -z "${dryRun}" ; then
        $dockerCmd > /dev/null 2> /dev/null
    fi
    resCode=$?

    if test ${resCode} -eq 0 ; then
        resultMessage="#   Result: ${green}Successful build${normal}\n"
        resultMessage="${resultMessage}#           $( docker images "${_image}" | grep -v "REPOSITORY" )"
        
    else
        resultMessage="#   Result: ${red}Error during build ($resCode)${normal}"
    fi

    echo "$resultMessage"

    return "${resCode}"
}

#
# Build and Tag a new docker image
#
tagImage ()
{
    image=${1}
    shift
    newTag=${1}
    
    echo "# Addl Tag: ${newTag}"
    ${dryRun} docker tag ${image} ${newTag}
}

errorExit ()
{
    msg=${1} && shift
    errorCode=${1}


    echo "${red}*** BUILD BREAK ***{normal}"
    echo "${red}$msg${normal}"
    exit "${errorCode}"
}

productsToBuild="federate access datasync directory datagovernance"
OSesToBuild="alpine centos ubuntu"
#
# Parse the provided arguments, if any
#
useCache="--no-cache --rm"
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
        
        --use-cache)
            useCache=" "
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

echo "
###########################################################################
#                 Ping Identity DevOps Docker Builds
#
#        Date: `date`
#     Product: ${productsToBuild}
#    Versions: ${versionsToBuild}
#         OSs: ${OSesToBuild}
#
###########################################################################
"

for product in common datacommon ; do
    buildAndTag "${product}" "na" "na" "latest"
    test ${?} -ne 0 && errorExit "${image}" 75
done

for shim in ${OSesToBuild} ; do
    # docker image rm -f ${p}/${c}base
    buildAndTag "base" "na" "${shim}" "${shim}" 
    test ${?} -ne 0 && errorExit "${image}" 76

    for product in ${productsToBuild} ; do
        if ! test -f "${c}${product}/versions" ; then
            buildAndTag "${product}" "na" "${shim}" "edge"
            test ${?} -ne 0 && errorExit "${image}" 77
        else
            firstImage=true
            if test -z "${versionsToBuild}" ; then
                prodVersionsToBuild=$( cat ${c}${product}/versions | grep -v '^#' )
            else
                prodVersionsToBuild="${versionsToBuild}"
            fi
            for VERSION in ${prodVersionsToBuild} ; do
                imageName="${p}/${c}${product}"
                imageTag="${VERSION}-${shim}-edge"

                buildAndTag "${product}" "${VERSION}" "${shim}" "${imageTag}" 
                test ${?} -ne 0 && errorExit "${image}" 78

                if ${firstImage} ; then
                    tagImage "${imageName}:${imageTag}" "${imageName}:${shim}"
                    tagImage "${imageName}:${imageTag}" "${p}/${c}${product}:${shim}-edge"

                    if test "${shim}" = "alpine" ; then
                      tagImage "${imageName}:${imageTag}" "${imageName}:edge"
                    fi
                    firstImage=false
                fi
                done
        fi
    done
done


echo "
###########################################################################
#               Images Built
#
#        Date: `date`
#
###########################################################################"

docker images -f since=pingidentity/pingcommon:latest -f dangling=false | sed 's/^/#   /'
