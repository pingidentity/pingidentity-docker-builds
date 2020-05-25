#- # Ping Identity Docker Image - `pingdelegator`
#- 
#- This docker image provides an NGINX instance with PingDelegator
#- that can be used in administering PingDirectory Users/Groups.
#-
#- ## Related Docker Images
#- - pingidentity/pingbase - Parent Image
#- 	>**This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://pingidentity-devops.gitbook.io/devops/dockerimagesref/pingbase)**
#- - pingidentity/pingcommon - Common Ping files (i.e. hook scripts)
#- - pingidentity/pingdownloader - Used to download product bits
#-

ARG PRODUCT
ARG SHIM
ARG SHIM_TAG
ARG VERSION
ARG REGISTRY
ARG GIT_TAG

FROM ${REGISTRY}/${PRODUCT}:staging-${VERSION}-${GIT_TAG} as product-staging
FROM ${REGISTRY}/pingcommon:${GIT_TAG} as common

FROM ${SHIM} as final-staging
ENV SHIM=${SHIM}

# get the product bits FIRST
COPY --from=product-staging ["/opt/","/opt/"]

# get Ping-wide common scripts
#   this needs to happen after the bits have been laid down
#   so they can be patched
COPY --from=common ["/opt/","/opt/"]

# apply product-specific hooks and patches
COPY ["/opt","/opt"]

# Run build
RUN ["/opt/build.sh"]

#
# the final image 
#
FROM ${REGISTRY}/pingbase:${GIT_TAG}
COPY --from=final-staging ["/","/"]

ENV DELEGATOR_PUBLIC_HOSTNAME=pingdelegator
ENV DELEGATOR_HTTP_PORT=8080
ENV DELEGATOR_HTTPS_PORT=8443


#-- The hostname for the public Ping Federate instance used for SSO.
ENV PF_ENGINE_PUBLIC_HOSTNAME=pingfederate

#-- The port for the public Ping Federate instance used for SSO.
#-- NOTE: If using port 443 along with a base URL with no specified port, set to
#-- an empty string.
ENV PF_ENGINE_PUBLIC_PORT=9031

#- The client id that was set up with Ping Federate for Ping Delegator.
ENV PF_DELEGATOR_CLIENTID=dadmin

#-- The hostname for the DS instance the app will be interfacing with. 
ENV PD_ENGINE_PRIVATE_HOSTNAME=pingdirectory

#-- The HTTPS port for the DS instance the app will be interfacing with. 
ENV PD_ENGINE_PRIVATE_PORT=443

#-- The length of time (in minutes) until the session will require a new login attempt
ENV DELEGATOR_TIMEOUT_LENGTH_MINS=30

#-- The filename used as the logo in the header bar, relative to this application's build directory.
#-- Note about logos: The size of the image will be scaled down to fit 22px of height and a max-width
#-- of 150px. For best results, it is advised to make the image close to this height and width ratio
#-- as well as to crop out any blank spacing around the logo to maximize its presentation.
#-- e.g. '${SERVER_ROOT_DIR}/html/delegator/images/my_company_logo.png'
ENV DELEGATOR_HEADER_BAR_LOGO=

#-- The namespace for the Delegated Admin API on the DS instance. In most cases, this does not need
#-- to be set here. e.g. 'dadmin/v2'
ENV DELEGATOR_DADMIN_API_NAMESPACE=

#-- Set to true if the "profile" scope is supported for the Delegated Admin OIDC client on
#-- PingFederate and you wish to use it to show the current user's name in the navigation.
ENV DELEGATOR_PROFILE_SCOPE_ENABLED=false


ENV STARTUP_COMMAND="nginx"
ENV STARTUP_FOREGROUND_OPTS="-c ${SERVER_ROOT_DIR}/etc/nginx.conf"
ENV STARTUP_BACKGROUND_OPTS="${STARTUP_FOREGROUND_OPTS}"

#- ## Run
#- To run a PingDelegator container with HTTPS_PORT=8443: 
#- 
#- ```shell
#-   docker run \
#-            --name pingdelegator \
#-            --publish 8443:8443 \
#-            --detach \
#-            pingidentity/pingdelegator
#- ```
#- 
#- ## Configuration
#- Be default, this does assume the default settings listed in the environment varialbes
#- above, and a running PingDirectory/PingFederate service.  To learn moure about how to
#- configure these instances, plese goto  
#- [Deploy PingDelegator Document](deployPingDelegator.md).
