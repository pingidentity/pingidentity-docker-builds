#!/usr/bin/env sh
${VERBOSE} && set -x

# shellcheck source=../lib.sh
. "${BASE}/lib.sh"

##################################################################
# Check for license file
#  1. If in SERVER_ROOT_DIR, good
#  2. If PING_IDENTITY_DEVOPS_USER and PING_IDENTITY_DEVOPS_KEY
#     provided then pull eval license from license server
#
#  TODO - Should probably add more mechanisms to pull from other
#         locations (i.e. vaults/secrets)
##################################################################
LICENSE_FILE="${LICENSE_DIR}/${LICENSE_FILE_NAME}"

if test -f "${LICENSE_FILE}" ; then
   licenseFound="true"
else
   if test -z "${PING_IDENTITY_DEVOPS_USER}" && test -z "${PING_IDENTITY_DEVOPS_KEY}" ; then
       echo_red "
##################################################################################
############################        ALERT        #################################
##################################################################################
# 
# No Ping Identity DevOps User or Key was passed.  Obtaining a generic short term
# eval license.
# 
# This automatic eval license will be deprecated soon, requiring your own
# personal DevOps User and Key.
# 
# More info on Product Licenses at:
#      https://pingidentity-devops.gitbook.io/devops/prod-license
# 
##################################################################################"
       PING_IDENTITY_DEVOPS_USER="${PING_IDENTITY_EVAL_USER}"
       PING_IDENTITY_DEVOPS_KEY="${PING_IDENTITY_EVAL_KEY}"
    fi

    ##################################################################
    # Let's get the license from the license server
    ##################################################################
    if ! test -z "${LICENSE_SHORT_NAME}" && ! test -z "${LICENSE_VERSION}" ; then
        echo "Pulling evauation license from Ping Identity for ${LICENSE_SHORT_NAME} v${LICENSE_VERSION}..."
        
        licenseCurlResult=$( curl -kL -w '%{http_code}' -G \
            --data-urlencode "product=${LICENSE_SHORT_NAME}" \
            --data-urlencode "version=${LICENSE_VERSION}" \
            --data-urlencode "user=${PING_IDENTITY_DEVOPS_USER}" \
            --data-urlencode "devops-key=${PING_IDENTITY_DEVOPS_KEY}" \
            --data-urlencode "devops-app=docker-${PING_PRODUCT}-${LICENSE_VERSION}" \
            "https://license.pingidentity.com/devops/licensekey" \
            -o "${LICENSE_FILE}" 2> /dev/null )
        if test $licenseCurlResult -eq 200 ; then
            echo "Successfully pulled evaluation license from Ping Identity"
            cat_indent "${LICENSE_FILE}"
            echo ""
            licenseFound="true"
        else
            echo "Unable to download evaluation product.lic (${licenseCurlResult}), most likely due to invalid PING_IDENTITY_DEVOPS_USER/PING_IDENTITY_DEVOPS_KEY"
            rm -f "${LICENSE_FILE}"
        fi
    else
        echo "Unable to determine PRODUCT_SHORT_NAME and PRODUCT_VERSION"
    fi
fi

if test ! "${licenseFound}" = "true" ; then
    echo "
##################################################################################
############################        ALERT        #################################
##################################################################################
# 
# License File absent
# More info on Product Licenses at:
#      https://pingidentity-devops.gitbook.io/devops/prod-license
# 
################################################################################"
    exit 89
fi