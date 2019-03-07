#!/usr/bin/env sh
c="ping"
p="${c}identity"

productsToBuild="common datacommon base ${1:-federate access datasync directory}"

for r in $productsToBuild ; do
    image=$p/${c}${r}
    docker image rm ${image}
    docker build --rm -t ${image} ${c}${r}
    if test ${?} -ne 0 ; then
        echo "*** BUILD BREAK ***"
        echo ${image}
        exit 77
    fi
done