#!/usr/bin/env sh
TOOL_NAME=$( basename "${0}" )
cd "$( dirname "${0}" )" || exit 1

##########################################################################################
usage ()
{
	if ! test -z "${1}" ; then
	   echo "Error: ${1}"
	fi

	cat <<END_USAGE1
Usage: ${TOOL_NAME} {options}
    where {options} include:
        *-p, --product:	the name of the product to download
                        one of:
END_USAGE1

	for prodName in ${availableProducts}; do
	    echo "                            ${prodName}"
	done
    
	cat <<END_USAGE2
        -v, --version: the version of the product to download.
		               by default, the downloader will pull the latest version
        -c, --conserve-name: use this option to conserve the original file name
                             by default, the downloader will rename the file product.zip
        -n, --dry-run:	this will cause the URL to be displayed but the
                        the bits not to be downloaded
END_USAGE2
# Future
#       -k, --devops-key: future Use. Ping DevOps ID used to download product and license
#		-s, --devops-secret: future Use. Ping DevOps Secret used to download product and license
	exit 77
}

##########################################################################################
# Get the properties used to provide the following items to this script:
#
#    Product Names - lowercase names used to request specific products (i.e. pingaccess)
#
#    Product Mappings - mapping from product name to filename used on server
#                       i.e. pingdirectory --> PingDirectory
#
#    Product URL - URL used to download the filename.  In most cases, a defaultURL is
#                  provided.  If a specific location is required, then a product URL 
#                  is specified (i.e. ldapsdkURL --> https://somewhereelse.com/ldapsdk...)
#
#    Product Latest Version - If no specific version is requested, the latest version will
#                             be retrieved (i.e. pingdirectoryLatestVersion=7.2.0.1)
##########################################################################################
getProps ()
{
    propsURL="https://s3.amazonaws.com/gte-bits-repo/"
    getBitsProps="gte-bits-repo.json"

	outputProps="/${getBitsProps}"

    curlResult=$( curl -kL -w '%{http_code}' ${propsURL}${getBitsProps} -o ${outputProps} 2>/dev/null )

	! test $curlResult -eq 200 && usage "Unable to get bits metadata (${getBitsProps})"

	availableProducts=$( jq -r '.products[].name' ${outputProps} )
}

##########################################################################################
# Based on the productLatestVersion variable, evaluate the version from the 
# properties file  
# Example: ...LatestVersion=1.0.0.0
##########################################################################################
getProductVersion ()
{
	latestVersion=$( jq -r ".products[] | select(.name==\"${product}\").latestVersion" ${outputProps} )

    if test -z "${version}" || test "${version}" = "latest" ; then
		version=${latestVersion}
        test "${version}" = "null" && usage "Unable to determine latest version for ${product}"
    fi

	test ${version} = ${latestVersion} && latestStr="(latest)"
}

##########################################################################################
# Based on the productMapping variable, evaluate the mapping from the 
# properties file  Note that there needs to be 2 consecutive evals
# since there may be a variable encoding in the variable
# Example: ...Mapping=productName-${version}.zip
##########################################################################################
getProductFile ()
{
	prodFile=$( jq -r ".products[] | select(.name==\"${product}\").mapping" ${outputProps} )
	prodFile=$(eval echo "$prodFile")
    test "${prodFile}" = "null" && usage "Unable to determine download file for ${product}"
}

##########################################################################################
# Based on the productURL variale, evaluate the URL from the
# properties file  Note that there needs to be 2 consecutive evals
# since there may be a variable encoding in the variable
# Example: ...URL=https://.../${version}/
##########################################################################################
getProductURL ()
{
	defaultURL=$( jq -r '.defaultURL' ${outputProps} ) 
	
	prodURL=$( jq -r ".products[] | select(.name==\"${product}\").url" ${outputProps} )
	
	prodURL=$( eval echo "$prodURL" )

	# If a produtURL wasn't provide, we should use the defaultDownloadURL
	test "${prodURL}" = "null" && prodURL=${defaultURL}

	test "${prodURL}" = "null" && usage "Unable to determine download URL for ${product}"
}

getProps

product=""
version=""
dryRun=""
output="product.zip"
while ! test -z "${1}" ; do
    case "${1}" in
        -p|--product)
			shift
			test -z "${1}" && usage "Product argument missing"
			
			# lowercase the argument value (the product name )
			product=$( echo ${1} | tr [A-Z] [a-z] )

	        for prodName in ${availableProducts}; do
	            if test "${product}" = "${prodName}" ; then
				    foundProduct=true
				fi
	        done
			;;
		-v|--version)
			shift
			test -z "${1}" && usage "Product version missing"
			version=${1}
			;;
#		-k|--devops-key)
#			shift
#			test -z "${1}" && usage "Ping DevOps Key missing"
#			devopsID=${1}
#			;;
#		-s|--devops-secret)
#			shift
#			test -z "${1}" && usage "Ping DevOps Secret missing"
#			devopsSecret=${1}
#			;;
		-c|--conserve-name)
		    conserveName=true
			;;
		-n|--dry-run)
			dryRun=true
			;;
		*)
			usage
			;;
	esac
    shift
done

# If we weren't passed a product option, then error
test -z ${product} && usage "Option --product {product} required"

# If we didn't find the product in the property file, then error
! test ${foundProduct} && usage "Invalid product name ${product}"

getProductVersion
getProductFile
getProductURL

# Construct the url used to pull the product down
url="${prodURL}${prodFile}"

# If we should conserve the name of the download, set the output to the
# productFile name
test ${conserveName} && output=${prodFile}

echo "
######################################################################
# Ping Downloader
#
#          PRODUCT: ${product}
#          VERSION: ${version} ${latestStr}"

if test -z "${dryRun}" ; then
	echo "#      DOWNLOADING: ${prodFile}"
	echo "#               TO: ${output}" 
	echo "######################################################################"
	cd /tmp || exit 2
	curlResult=$( curl -kL -w '%{http_code}' "${url}" -o "${output}" )

	! test $curlResult -eq 200 && echo "Unable to download ${prodFile}" && exit 1
else
	echo "#              URL: ${url}"
	echo "######################################################################"
fi

# Need this exit of 0, since the last test of the curlResult will return a 1
exit 0