#!/usr/bin/env sh
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
buildAndTag ()
{
    product=${1}
    shift
    tag=${1}
    shift
    image=${p}/${c}${product}:${tag}

    docker image rm ${image} > /dev/null 2>/dev/null
    
    dockerCmd="docker build --no-cache --rm $* -t ${image} ${c}${product}"

    echo ""
    echo "###########################################################################"
    echo "# Building: $image"
    echo "#  Command: $dockerCmd"

    if test -z "${dryRun}" ; then
        $dockerCmd > /dev/null 2> /dev/null
    fi
    resCode=$?

    if test ${resCode} -eq 0 ; then
        resultMessage="#   Result: ${green}Successful build${normal}\n"
        resultMessage+="#           $( docker images "${image}" | grep -v "REPOSITORY" )"
        
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
    buildAndTag ${product} latest
    test ${?} -ne 0 && errorExit "${image}" 75
done

for shim in ${OSesToBuild} ; do
    # docker image rm -f ${p}/${c}base
    buildAndTag base ${shim} --build-arg SHIM=${shim}
    test ${?} -ne 0 && errorExit "${image}" 76

    for product in ${productsToBuild} ; do
        if ! test -f "${c}${product}/versions" ; then
            buildAndTag ${product} edge --build-arg SHIM=${shim}
            test ${?} -ne 0 && errorExit "${image}" 77
        else
            firstImage=true
            if test -z "${versionsToBuild}" ; then
                prodVersionsToBuild=$( cat ${c}${product}/versions | grep -v '^#' )
            else
                prodVersionsToBuild="${versionsToBuild}"
            fi
            for VERSION in ${prodVersionsToBuild} ; do

                buildAndTag ${product} ${VERSION}-${shim}-edge --build-arg VERSION=${VERSION}  --build-arg SHIM=${shim}
                test ${?} -ne 0 && errorExit "${image}" 78

                if ${firstImage} ; then
                    tagImage "${p}/${c}${product}:${VERSION}-${shim}-edge" "${p}/${c}${product}:${shim}"
                    tagImage "${p}/${c}${product}:${VERSION}-${shim}-edge" "${p}/${c}${product}:${shim}-edge"

                    if test "${shim}" = "alpine" ; then
                      tagImage "${p}/${c}${product}:${VERSION}-${shim}-edge" "${p}/${c}${product}:edge"
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
