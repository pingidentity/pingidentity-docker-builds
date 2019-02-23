#!/usr/bin/env sh
c="ping"
p="${c}identity"

for r in common base federate ; do
    image=$p/${c}${r}
    cd ${c}${r}
    docker image rm ${image}
    docker build --rm -t ${image} .
    if test $? -ne 0 ; then
        echo "*** BUILD BREAK ***"
        echo ${image}
        exit 77
    fi
    cd ..
done
