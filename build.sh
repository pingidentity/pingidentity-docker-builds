#!/usr/bin/env sh
${VERBOSE} && set -x

c="ping"
p="${c}identity"


buildAndTag ()
{
    product=${1}
    shift
    tag=${1}
    shift
    image=${p}/${c}${product}:${tag}
    docker image rm ${image} > /dev/null 2>/dev/null
    docker build --no-cache --rm $* -t ${image} ${c}${product}
    return ${?}
}

productsToBuild="${1:-federate access datasync directory}"

for product in common datacommon ; do
    buildAndTag ${product} latest
    if test ${?} -ne 0 ; then
        echo "*** BUILD BREAK ***"
        echo "${image}"
        exit 75
    fi
done

for shim in alpine ubuntu centos ; do
    # docker image rm -f ${p}/${c}base
    buildAndTag base ${shim} --build-arg SHIM=${shim}
    if test ${?} -ne 0 ; then
        echo "*** BUILD BREAK ***"
        echo "${image}"
        exit 76
    fi

    for product in $productsToBuild ; do
        if ! test -f ${c}${product}/versions ; then
            buildAndTag ${product} edge --build-arg SHIM=${shim}
            if test ${?} -ne 0 ; then
                echo "*** BUILD BREAK ***"
                echo "${image}"
                exit 77
            fi
        else
            firstImage=true
            for VERSION in $( cat ${c}${product}/versions | grep -v '^#' ) ; do
                buildAndTag ${product} ${VERSION}-${shim}-edge --build-arg VERSION=${VERSION}  --build-arg SHIM=${shim}
                if test ${?} -ne 0 ; then
                    echo "*** BUILD BREAK ***"
                    echo "${image}"
                    exit 78
                fi
                if ${firstImage} && test "${shim}" = "alpine" ; then
                    docker tag ${p}/${c}${product}:${VERSION}-${shim}-edge ${p}/${c}${product}:edge
                    firstImage=false
                fi
            done
        fi
    done
done