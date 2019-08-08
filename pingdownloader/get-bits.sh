#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
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

This tool can be used to download either product binaries (.zip) files or 
product evaluation licenses (.lic).  By default, the product binaries will
be downlaoded.  If the -l option is provided then only a license will be 
downloaded.  If a license is pulled, a Ping DevOps Key/User is required.

Options include:
    *-p, --product {product-name}    The name of the product bits/license to download
    -v, --version {version-num}      The version of the product bits/license to download.
                                     by default, the downloader will pull the 
                                     latest version

For product downloads:
    -c, --conserve-name              Use this option to conserve the original 
                                     file name by default, the downloader will
                                     rename the file product.zip
    -n, --dry-run:                   This will cause the URL to be displayed 
                                     but the the bits not to be downloaded


For license downloads:
    *-l, --license                   Download a license file
    *-u, --devops-user {devops-user} Your Ping DevOps Username
    *-k, --devops-key {devops-key}   Your Ping DevOps Key
    -a, --devops-app {app-name}      Your App Name
    
Where {product-name} is one of:
END_USAGE1

	for prodName in ${availableProducts}; do
	    echo "   ${prodName}"
	done
    
	cat <<END_USAGE2

Example:

    Pull the latest version of PingDirectory down to a product.zip file

        ${TOOL_NAME} -p pingdirectory

    Pull the 9.3 version of PingFederate eval license file down to a product.lic

        ${TOOL_NAME} -p pingfederate -v 9.3 -l -u john@example.com \\
                    -k 94019ea5-ecca-49a4-8962-990130df3815 -a pingdownloader

END_USAGE2
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
    curlResult=$( curl -kL -w '%{http_code}' ${propsURL}${getBitsProps} -o ${outputProps} 2>/dev/null )

	! test $curlResult -eq 200 && usage "Unable to get bits metadata. Network Issue?"

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

propsURL="https://s3.amazonaws.com/gte-bits-repo/"
getBitsProps="gte-bits-repo.json"

outputProps="/tmp/${getBitsProps}"

getProps

product=""
version=""
dryRun=""
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
		-l|--license)
		    pullLicense=true
			;;
		-k|--devops-key)
			shift
			test -z "${1}" && usage "Ping DevOps Key missing"
			devopsKey=${1}
			;;
		-u|--devops-user)
			shift
			test -z "${1}" && usage "Ping DevOps Username missing"
			devopsUser=${1}
			;;
		-a|--devops-app)
			shift
			test -z "${1}" && usage "Ping DevOps AppName missing"
			devopsApp=${1}
			;;
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

if test ${pullLicense} ; then
    test -z ${devopsKey} && usage "Option --devops-key {devops-key} required for eval license"
    test -z ${devopsUser} && usage "Option --devops-user {devops-user} required for eval license"
    test -z ${devopsApp} && devopsApp="pingdownloader"

    case "${product}" in
        pingdirectory|pingdatasync|pingdirectoryproxy|pingdatametrics)
           productShortName="PD"
           ;;
        pingaccess)
           productShortName="PA"
           ;;
        pingdatagovernance)
           productShortName="PDG"
           ;;
        pingdatagovernancepap)
           productShortName="PDG"
           ;;
        pingfederate)
           productShortName="PF"
           ;;
        *)
           usage "No license files available for $product"
        ;;
    esac
    url="https://license.pingidentity.com/devops/v2/license"
    
    output="product.lic"
else
    # Construct the url used to pull the product down
    url="${prodURL}${prodFile}"

    # If we should conserve the name of the download, set the output to the
    # productFile name
    output="product.zip"

    test ${conserveName} && output=${prodFile}
fi


echo "
######################################################################
# Ping Downloader
#
#          PRODUCT: ${product}
#          VERSION: ${version} ${latestStr}"

if test ${pullLicense} ; then
        echo "#      DOWNLOADING: product.lic"  
    	echo "#               TO: ${output}" 
	    cd /tmp || exit 2
	    curlResult=$( curl -kL -w '%{http_code}' -G \
          -H "product: ${productShortName}" \
          -H "version: ${version}" \
          -H "devops-user: ${devopsUser}" \
          -H "devops-key: ${devopsKey}" \
          -H "devops-app: ${devopsApp}" \
          "${url}" -o "${output}" )

	    ! test $curlResult -eq 200 && echo "Unable to download product.lic" && exit 1
else
    if test -z "${dryRun}" ; then
    	echo "#      DOWNLOADING: ${prodFile}"
    	echo "#               TO: ${output}" 
	    cd /tmp || exit 2
	    curlResult=$( curl -kL -w '%{http_code}' "${url}" -o "${output}" )

	    ! test $curlResult -eq 200 && echo "Unable to download ${prodFile}" && exit 1
    else
	    echo "#              URL: ${url}"
    fi
fi

echo "######################################################################"

# Need this exit of 0, since the last test of the curlResult will return a 1
exit 0