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
for product in common datacommon base ; do
    buildAndTag ${product} latest
    if test ${?} -ne 0 ; then
        echo "*** BUILD BREAK ***"
        echo ${image}
        exit 76
    fi
done

for product in $productsToBuild ; do
    if ! test -f ${c}${product}/versions ; then
        buildAndTag ${product} edge
        if test ${?} -ne 0 ; then
            echo "*** BUILD BREAK ***"
            echo ${image}
            exit 77
        fi
    else
        firstImage=true
        for VERSION in $( cat ${c}${product}/versions | grep -v '^#' ) ; do
            buildAndTag ${product} ${VERSION}-edge --build-arg VERSION=${VERSION}
            if test ${?} -ne 0 ; then
                echo "*** BUILD BREAK ***"
                echo ${image}
                exit 78
            fi
            if ${firstImage} ; then
                docker tag ${p}/${c}${product}:${VERSION}-edge ${p}/${c}${product}:edge
                firstImage=false
            fi
        done
    fi
done