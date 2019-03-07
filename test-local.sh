#!/usr/bin/env sh
test ! -z "${VERBOSE}" && ${VERBOSE} && set -x
usage ()
{
    cat <<END
    Usage: ${0} [product-name]
    product-name: access federate directory datasync
                  the script will run all the test if nothing is provided
END
}

if test ! -z "${1}" ; then
    case "${1}" in
        access|federate|directory|datasync)
            ;;
        *)
            usage
            exit 77
            ;;
    esac
fi

p=ping
for i in ${1:-access federate directory datasync} ; do
    docker-compose -f ${p}${i}/build.test.yml up --exit-code-from sut
    if test ${?} -ne 0 ; then
        echo "TEST FAILURE for ${p}${i}"
        exit 1
    fi
    docker-compose -f ${p}${i}/build.test.yml down
done