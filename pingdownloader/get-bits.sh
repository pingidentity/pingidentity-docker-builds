#!/bin/sh
TOOL_NAME=$( basename $0 )
cd $( dirname $0 )
thisLocation=$( pwd )

usage ()
{
	cat <<END_USAGE
Usage: ${TOOL_NAME} {options}
    where {options} include:
		 -c, --conserve-name: use this option to conserve the original file name
		 					  by default, the downloader will rename the file product.zip
    	*-p, --product:	the name of the product to download
    					one of:
    						pingaccess
    						pingdatagovernance
    						pingdatasync
    						pingdirectory
    						pingdirectoryproxy
    						pingfederate
    						ldapsdk
							delegator
    	*-v, --version:	the version of the product to download.
    	 -n, --dry-run:	this will cause the URL to be displayed but the
    					the bits not to be downloaded
END_USAGE
	exit 77
}

product=""
version=""
dryRun=""
output="-o product.zip"
while ! test -z "${1}" ; do
    case "${1}" in
        -p|--product)
			shift
			if test -z "${1}" ; then
				echo "Product argument missing"
				usage
			fi
			# lowercase the argument value (the product name )
			providedValue=$( echo ${1} | tr [A-Z] [a-z] )
			;;
		-v|--version)
			if test -z "${1}" ; then
				echo "Product version missing"
				usage
			fi
			shift
			version=${1}
			;;
		-c|--conserve-name)
			output="-O"
			;;
		-n|--dry-run)
			dryRun="true"
			;;
		*)
			usage
			;;
	esac
shift
done

case "${providedValue}" in
	pingaccess|pingdatagovernance|pingdatasync|pingdirectory|pingdirectoryproxy|pingfederate|ldapsdk|delegator)
		product=${providedValue}
		;;
	*)
		echo "Invalid product name ${1}"
		usage
		;;
esac

test -z "${version}" && echo "Version must be provided" && usage

url="https://s3.amazonaws.com/gte-bits-repo/"

case "${product}" in
	pingdatagovernance)
		url="${url}PingDataGovernance"
		;;
	pingdatasync)
		url="${url}PingDataSync"
		;;
	pingdirectory)
		url="${url}PingDirectory"
		;;
	pingdirectoryproxy)
		url="${url}PingDirectoryProxy"
		;;
	delegator)
		url="${url}pingdirectory-delegator"
		;;
	ldapsdk)
		url="https://github.com/pingidentity/ldapsdk/releases/download/${version}/unboundid-ldapsdk"
		;;
	*)
		url="${url}${product}"
		;;
esac
url="${url}-${version}.zip"

if test -z "${dryRun}" ; then
	cd /tmp
	curl -kL ${url} ${output}
else
	echo ${url}
fi
