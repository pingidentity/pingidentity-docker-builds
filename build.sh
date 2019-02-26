#!/usr/bin/env sh
c="ping"
p="${c}identity"

for r in common datacommon base federate access datasync directory ; do
    image=$p/${c}${r}
    # https://github.com/koalaman/shellcheck/wiki/SC2103
    (
    cd ${c}${r} || exit 77
    docker image rm ${image}
    docker build --rm -t ${image} .
    )
    if test $? -ne 0 ; then
        echo "*** BUILD BREAK ***"
        echo ${image}
        exit 77
    fi
done