#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
test "${VERBOSE}" = "true" && set -x

# location of setup-arguments file used for PingData products
SETUP_ARGUMENTS_FILE="${PD_PROFILE}/setup-arguments.txt"
_configLDIF="${SERVER_ROOT_DIR}/config/config.ldif"

# Location to hold JVM state information
JVM_STATE_DIR="${OUT_DIR}/jvm-settings-state"

buildPasswordFileOptions() {
    #
    # Support legacy password file locations
    # Set these as the defaults.  They will be overridden by the next section.
    #
    _legacySecretLocation="${STAGING_DIR}/.sec"
    test -z "${ROOT_USER_PASSWORD_FILE}" && test -f "${_legacySecretLocation}/root-user-password" &&
        echo "WARNING: A root-user-password file found in the legacy secret location '${_legacySecretLocation}'" &&
        echo "         Consider moving to a more secure vault secret." &&
        ROOT_USER_PASSWORD_FILE="${_legacySecretLocation}/root-user-password"

    test -z "${ADMIN_USER_PASSWORD_FILE}" && test -f "${_legacySecretLocation}/admin-user-password" &&
        echo "WARNING: A admin-user-password file found in the legacy secret location '${_legacySecretLocation}'" &&
        echo "         Consider moving to a more secure vault secret." &&
        ADMIN_USER_PASSWORD_FILE="${_legacySecretLocation}/admin-user-password"

    test -z "${ENCRYPTION_PASSWORD_FILE}" && test -f "${_legacySecretLocation}/encryption-password" &&
        echo "WARNING: A encryption-password file found in the legacy secret location '${_legacySecretLocation}'" &&
        echo "         Consider moving to a more secure vault secret." &&
        ENCRYPTION_PASSWORD_FILE="${_legacySecretLocation}/encryption-password"

    # If no SECRETS_DIR (/run/secrets) exists, then create a /tmp/secrets directory to be
    # used for now if password files need to be created.
    _passwordFilesDir="${SECRETS_DIR}"
    if test ! -d "${SECRETS_DIR}"; then
        echo_yellow "WARNING: Important that the orchestration environment create a tmpfs for '${SECRETS_DIR}'"
        echo_yellow "         Using 'tmp/secrets' for now."
        _passwordFilesDir="/tmp/secrets"
        mkdir -p "${_passwordFilesDir}"
    else
        # Try writing a file to the SECRETS_DIR. If we don't have permissions, /tmp/secrets will have to be used instead
        touch "${SECRETS_DIR}"/buildPasswordFileOptions-test-file 2> /dev/null
        if test ${?} -ne 0; then
            echo_yellow "WARNING: Unable to write password files to '${SECRETS_DIR}'"
            echo_yellow "         Using 'tmp/secrets' for now."
            _passwordFilesDir="/tmp/secrets"
            mkdir -p "${_passwordFilesDir}"
        else
            rm "${SECRETS_DIR}"/buildPasswordFileOptions-test-file
        fi
    fi

    #
    # Set the default password files if not set at this point
    #
    test -z "${ROOT_USER_PASSWORD_FILE}" &&
        ROOT_USER_PASSWORD_FILE="${_passwordFilesDir}/root-user-password" &&
        echo "Using ROOT_USER_PASSWORD_FILE '${ROOT_USER_PASSWORD_FILE}'"

    test -z "${ADMIN_USER_PASSWORD_FILE}" &&
        ADMIN_USER_PASSWORD_FILE="${_passwordFilesDir}/admin-user-password" &&
        echo "Using ADMIN_USER_PASSWORD_FILE '${ADMIN_USER_PASSWORD_FILE}'"

    test -z "${ENCRYPTION_PASSWORD_FILE}" &&
        ENCRYPTION_PASSWORD_FILE="${_passwordFilesDir}/encryption-password" &&
        echo "Using ENCRYPTION_PASSWORD_FILE '${ENCRYPTION_PASSWORD_FILE}'"

    export_container_env ROOT_USER_PASSWORD_FILE ADMIN_USER_PASSWORD_FILE ENCRYPTION_PASSWORD_FILE

    # If PING_IDENTITY_PASSWORD has no value, give it one here. This ensures that we aren't
    # trying to use password files with no contents.
    if test -z "${PING_IDENTITY_PASSWORD}"; then
        PING_IDENTITY_PASSWORD=2FederateM0re
    fi

    # Create the possible PASSWORD_FILEs if they don't already exist
    #
    #   ROOT_USER_PASSWORD_FILE
    #   ENCRYPTION_PASSWORD_FILE
    #   ADMIN_USER_PASSWORD_FILE

    if test -n "${ROOT_USER_PASSWORD_FILE}" && ! test -f "${ROOT_USER_PASSWORD_FILE}"; then
        mkdir -p "$(dirname "${ROOT_USER_PASSWORD_FILE}")"
        echo "${PING_IDENTITY_PASSWORD}" > "${ROOT_USER_PASSWORD_FILE}"
    fi
    if test -n "${ENCRYPTION_PASSWORD_FILE}" && ! test -f "${ENCRYPTION_PASSWORD_FILE}"; then
        mkdir -p "$(dirname "${ENCRYPTION_PASSWORD_FILE}")"
        echo "${PING_IDENTITY_PASSWORD}" > "${ENCRYPTION_PASSWORD_FILE}"
    fi
    if test -n "${ADMIN_USER_PASSWORD_FILE}" && ! test -f "${ADMIN_USER_PASSWORD_FILE}"; then
        mkdir -p "$(dirname "${ADMIN_USER_PASSWORD_FILE}")"
        echo "${PING_IDENTITY_PASSWORD}" > "${ADMIN_USER_PASSWORD_FILE}"
    fi
}

#
# Check for the cert files in the directory passed, and if found, then set
# the certFile
_checkAndSetCertDefaults() {
    _checkDir="${1}"

    if test -f "${_checkDir}/${_certVarLower}.pin"; then
        if test -f "${_checkDir}/${_certVarLower}"; then
            eval "${_certFile}=${_checkDir}/${_certVarLower}"
            eval "${_certType}=jks"
        elif test -f "${_checkDir}/${_certVarLower}.p12"; then
            eval "${_certFile}=${_checkDir}/${_certVarLower}.p12"
            eval "${_certType}=pkcs12"
        fi
        eval "${_certPinFile}=${_checkDir}/${_certVarLower}.pin"
    fi
}

#
# This is a helper function which will validate the certificate files and pins
#
# Example: Resulting validating the variables and files/pins for arg:
#
#   arg=keystore            arg=truststore
#       KEYSTORE_FILE           TRUSTSTORE_FILE
#       KEYSTORE_PIN_FILE       TRUSTSTORE_PIN_FILE
#       KEYSTORE_TYPE           TRUSTSTORE_TYPE
#
_validateCertificateOptions() {
    # certVar must be either keystore or truststore
    _certVar=$(toUpper "${1}")
    _certVarLower=$(toLower "${1}")

    _certFile="${_certVar}_FILE"
    _certPinFile="${_certVar}_PIN_FILE"
    _certType="${_certVar}_TYPE"

    _certFileVal=$(get_value "${_certFile}")
    _certPinFileVal=$(get_value "${_certPinFile}")
    _certTypeVal=$(get_value "${_certType}")

    if test -n "${_certFileVal}"; then
        if ! test -f "${_certFileVal}"; then
            echo_red "**********"
            echo_red "${_certFile} value [${_certFileVal}] is invalid: the specified file does not exist"
            exit 75
        fi
        if test "$(toLower "${_certTypeVal}")" != "pem"; then
            if test -z "${_certPinFileVal}"; then
                echo_red "**********"
                echo_red "A value for ${_certPinFile} must be specified when ${_certFile} is provided"
                exit 75
            fi
            if ! test -f "${_certPinFileVal}"; then
                echo_red "**********"
                echo_red "${_certPinFile} value [${_certPinFileVal}] is invalid: the specified file does not exist"
                exit 75
            fi
        fi
        if test -z "${_certTypeVal}"; then
            # Attempt to get the store type from the store file name
            _storeFileLower=$(toLower "${_certFileVal}")
            case "${_storeFileLower}" in
                *.bcfks)
                    eval "${_certType}=bcfks"
                    ;;
                *.pem)
                    eval "${_certType}=pem"
                    ;;
                *.p12)
                    eval "${_certType}=pkcs12"
                    ;;
                *)
                    # No KEYSTORE_TYPE is set. Defaulting to JKS
                    eval "${_certType}=jks"
                    ;;
            esac
        else
            # lowercase the truststore type
            _storeTypeLower=$(toLower "${_certTypeVal}")
            case "${_storeTypeLower}" in
                pkcs12 | jks | bcfks | pem)
                    eval "${_certType}=${_storeTypeLower}"
                    ;;
                *)
                    echo_red "**********"
                    echo_red "Unsupported ${_certType} value [${_certTypeVal}]"
                    echo_red "Value must be PKCS12 or JKS"
                    exit 75
                    ;;
            esac
        fi
    else
        #
        # The cert file value isn't set, so we will attempt to set them
        # based on the SECRETS_DIR.
        #

        _checkAndSetCertDefaults "${SECRETS_DIR}"
    fi
}

#
# Checks if the product is PingAuthorize-PAP, which requires
# slightly different certificate options.
#
_isPingAuthorizePap() {
    test "${PING_PRODUCT}" = "PingAuthorize-PAP"
}

#
# Creates a set of certificate options used during the setup and restart of a
# PingData product
#
# Options set will include some of the following depending on whether files and
# certificate names are included.:
#
#   generate certification if no keystore file provided
#     --generateSelfSignedCertificate
#
#   keystore info
#     --usePkcs12KeyStore {file}
#     --useJavaKeyStore {file}
#     --keyStorePasswordFile {file}
#
#   truststore info
#     --usePkcs12TrustStore {file}
#     --useJavaTrustStore {file}
#     --trustStorePasswordFile {file}
#
#   certificate nickname used in keystore
#     --certNickname {nickname}
getCertificateOptions() {

    # Validate keystore options
    _validateCertificateOptions keystore

    # pingauthorizepap does not consume truststore options
    if ! _isPingAuthorizePap; then
        _validateCertificateOptions truststore
    fi

    # Create the certificate options
    if test -z "${KEYSTORE_FILE}"; then
        certificateOptions="--generateSelfSignedCertificate"
    else
        if _isPingAuthorizePap; then
            case "$(toLower "${KEYSTORE_TYPE}")" in
                pkcs12)
                    certificateOptions="--pkcs12KeyStorePath ${KEYSTORE_FILE}"
                    ;;
                jks)
                    certificateOptions="--javaKeyStorePath ${KEYSTORE_FILE}"
                    ;;
                *)
                    echo_red "The provided value [${KEYSTORE_TYPE}] for variable KEYSTORE_TYPE is not supported"
                    exit 75
                    ;;
            esac
        else
            case "$(toLower "${KEYSTORE_TYPE}")" in
                pkcs12)
                    certificateOptions="--usePkcs12KeyStore ${KEYSTORE_FILE}"
                    ;;
                jks)
                    certificateOptions="--useJavaKeyStore ${KEYSTORE_FILE}"
                    ;;
                bcfks)
                    certificateOptions="--useBCFKSKeystore ${KEYSTORE_FILE}"
                    ;;
                pem)
                    certificateOptions="--certificatePrivateKeyPEMFile ${KEYSTORE_FILE}"
                    ;;
                *)
                    echo_red "The provided value [${KEYSTORE_TYPE}] for variable KEYSTORE_TYPE is not supported"
                    exit 75
                    ;;
            esac
        fi
        if test -n "${KEYSTORE_PIN_FILE}"; then

            # pingauthorizepap consumes the keystore pin file through an environment variable in start-server.
            if _isPingAuthorizePap; then
                certificateOptions="${certificateOptions} --keystorePassword 2FederateM0re"
            else
                certificateOptions="${certificateOptions} --keyStorePasswordFile ${KEYSTORE_PIN_FILE}"
            fi
        elif test "$(toLower "${KEYSTORE_TYPE}")" != "pem"; then
            echo_red "KEYSTORE_PIN_FILE is required if a KEYSTORE_FILE is provided."
            exit 75
        fi
    fi

    # Add the truststore certificate options
    if test -n "${TRUSTSTORE_FILE}" && ! _isPingAuthorizePap; then
        case "$(toLower "${TRUSTSTORE_TYPE}")" in
            pkcs12)
                certificateOptions="${certificateOptions} --usePkcs12TrustStore ${TRUSTSTORE_FILE}"
                ;;
            jks)
                certificateOptions="${certificateOptions} --useJavaTrustStore ${TRUSTSTORE_FILE}"
                ;;
            bcfks)
                certificateOptions="${certificateOptions} --useBCFKSTruststore ${TRUSTSTORE_FILE}"
                ;;
            pem)
                certificateOptions="${certificateOptions} --certificateChainPEMFile ${TRUSTSTORE_FILE}"
                ;;
            *)
                echo_red "The provided value [${TRUSTSTORE_TYPE}] for variable TRUSTSTORE_TYPE is not supported"
                exit 75
                ;;
        esac
    fi
    if test -n "${TRUSTSTORE_PIN_FILE}" && ! _isPingAuthorizePap; then
        certificateOptions="${certificateOptions} --trustStorePasswordFile ${TRUSTSTORE_PIN_FILE}"
    fi

    # get the CERTIFICATE_NICKNAME.
    #
    SELF_CERT_GEN="--generateSelfSignedCertificate"
    case "${SELF_CERT_GEN}" in
        "${certificateOptions}")
            # Must either unset CERTIFICATE_NICKNAME or set to server-cert if generateSelfSignedCertificate is set.
            echo_yellow 'Using self signed certificate, CERTIFICATE_NICKNAME set to "server-cert".' >&2
            CERTIFICATE_NICKNAME="server-cert"
            ;;
        *)
            if _isPingAuthorizePap; then
                certificateOptions="${certificateOptions} --certNickname ${CERTIFICATE_NICKNAME}"
            fi
            ;;
    esac

    if test -z "${CERTIFICATE_NICKNAME}"; then
        CERTIFICATE_NICKNAME=$(
            keytool -list \
                -keystore "${KEYSTORE_FILE}" \
                -storetype "${KEYSTORE_TYPE}" \
                -protected \
                -rfc 2> /dev/null | awk 'BEGIN { }
                      /^Alias name: / { certAlias=$3 }
                      /^Entry type: PrivateKeyEntry/  { ++n; privateKeyEntry=certAlias }
                    END { if (n == 1) print privateKeyEntry }'
        )

        test -z "${CERTIFICATE_NICKNAME}" && CERTIFICATE_NICKNAME="server-cert"
    fi

    if ! _isPingAuthorizePap; then
        certificateOptions="${certificateOptions} --certNickname ${CERTIFICATE_NICKNAME}"
    fi
    echo "${certificateOptions}"
}

# if an encryption password file is provided, then this will provide the option to use
# that file during setup.  Otherwise, a random passphrase will be used.
getEncryptionOption() {
    encryptionOption="--encryptDataWithRandomPassphrase"

    if test -f "${ENCRYPTION_PASSWORD_FILE}"; then
        encryptionOption="--encryptDataWithPassphraseFromFile ${ENCRYPTION_PASSWORD_FILE}"
    fi

    echo "${encryptionOption}"
}

# returns the jvm option used during the setup of a PingData product
getJvmOptions() {
    jvmOptions=""
    if test "${PING_PRODUCT}" = "PingDirectory"; then
        # If PingDirectory 8.1.0.0 or greater is run and the MAX_HEAP_SIZE is 384m, then it's
        # assumed to have never been set so it'll update it to the minimum needed
        # for version 8.1.0.0 or greater.
        if test "${MAX_HEAP_SIZE}" = "384m"; then
            MAX_HEAP_SIZE="768m"
        fi
    fi

    case "${JVM_TUNING}" in
        NONE | AGGRESSIVE | SEMI_AGGRESSIVE)
            jvmOptions="${jvmOptions} --jvmTuningParameter ${JVM_TUNING}"
            ;;
        *)
            echo_red "**********"
            echo_red "Unsupported JVM_TUNING value [${JVM_TUNING}]"
            echo_red "Value must be NONE, AGGRESSIVE or SEMI_AGGRESSIVE"
            exit 75
            ;;
    esac

    if test -n "${MAX_HEAP_SIZE}" && ! test "${MAX_HEAP_SIZE}" = "AUTO"; then
        jvmOptions="${jvmOptions} --maxHeapSize ${MAX_HEAP_SIZE}"
    fi

    echo "${jvmOptions}"
}

# Generates a setup-arguments.txt file passed as first parameter
generateSetupArguments() {
    # Create product specific setup arguments and manage-profile setup arguments
    case "${PING_PRODUCT}" in
        PingDataSync | PingDirectoryProxy | PingAuthorize)
            _pingDataSetupArguments=""
            PING_DATA_MANAGE_PROFILE_SETUP_ARGS=""
            ;;
        PingDirectory)
            _pingDataSetupArguments="${encryptionOption} \
                                    --baseDN \"${USER_BASE_DN}\" \
                                    --addBaseEntry "
            _doesStartWith8=$(echo "${LICENSE_VERSION}" | sed 's/^8.*//')
            if test -z "${_doesStartWith8}"; then
                PING_DATA_MANAGE_PROFILE_SETUP_ARGS="--addMissingRdnAttributes"
            fi
            PING_DATA_MANAGE_PROFILE_SETUP_ARGS="${PING_DATA_MANAGE_PROFILE_SETUP_ARGS:+${PING_DATA_MANAGE_PROFILE_SETUP_ARGS} }--rejectFile /tmp/rejects.ldif ${_skipImports:=}"
            if test "${FIPS_MODE_ON}" = "true"; then
                # a provision is made for the future case where we would support multiple
                # FIPS providers but since currently we do not, we check that the
                # only correct value is provided or we alert and die in place
                if test -z "${FIPS_PROVIDER}" || ! test "${FIPS_PROVIDER}" = "BCFIPS"; then
                    echo_red "When FIPS mode is enabled, the only FIPS provider currently supported is BCFIPS."
                    exit 182
                fi
                _fips_mode_on="--fips-provider ${FIPS_PROVIDER}"
            fi
            ;;
        *)
            echo_red "Unknown PING_PRODUCT value [${PING_PRODUCT}]"
            exit 182
            ;;
    esac

    if test "${RUN_PLAN}" = "RESTART"; then
        _prevSetupArgs="${SERVER_ROOT_DIR}/config/.manage-profile-setup-arguments.txt"
        _prevLdapsPort=$(sed -n 's/.*--ldapsPort \([0-9]*\).*/\1/p' < "${_prevSetupArgs}")
        _prevLdapPort=$(sed -n 's/.*--ldapPort \([0-9]*\).*/\1/p' < "${_prevSetupArgs}")
        _prevHttpsPort=$(sed -n 's/.*--httpsPort \([0-9]*\).*/\1/p' < "${_prevSetupArgs}")

        # Check to see if there is an attempt to change the ports.  If so, emit an error and fail
        # LDAP_PORT is defined. Disable shellcheck.
        # shellcheck disable=SC2153
        if test "${_prevLdapPort}" != "${LDAP_PORT}" ||
            test "${_prevLdapsPort}" != "${LDAPS_PORT}" ||
            test "${_prevHttpsPort}" != "${HTTPS_PORT}"; then
            echo_red "*****"
            echo_red "LDAP/LDAPS/HTTPS ports from original settings may not be changed on restart."
            echo_red "   Service         Original Setting     Attempt"
            echo_red "   LDAP_PORT       ${_prevLdapPort}                  ${LDAP_PORT}"
            echo_red "   LDAPS_PORT      ${_prevLdapsPort}                  ${LDAPS_PORT}"
            echo_red "   HTTPS_PORT      ${_prevHttpsPort}                  ${HTTPS_PORT}"
            echo_red "Please make any adjustments in dsconfig commands."
            echo_red "*****"
            container_failure 20 "Resolve the issues with your orchestration environment variables"
        fi
    fi

    echo "Generating ${SETUP_ARGUMENTS_FILE}"
    cat << EOSETUP > "${SETUP_ARGUMENTS_FILE}"
    --verbose \
    --acceptLicense \
    --skipPortCheck \
    --instanceName ${INSTANCE_NAME} \
    --location ${LOCATION} \
    $(test ! -z "${LDAP_PORT}" && echo "--ldapPort ${LDAP_PORT}") \
    $(test ! -z "${LDAPS_PORT}" && echo "--ldapsPort ${LDAPS_PORT}") \
    $(test ! -z "${HTTPS_PORT}" && echo "--httpsPort ${HTTPS_PORT}") \
    --enableStartTLS \
    ${jvmOptions} \
    ${certificateOptions} \
    --rootUserDN "${ROOT_USER_DN}" \
    --rootUserPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    ${_pingDataSetupArguments} \
    ${_fips_mode_on} \
    ${ADDITIONAL_SETUP_ARGS}
EOSETUP

}

#
getPingDataInstanceName() {
    if test "${RUN_PLAN}" = "RESTART"; then
        grep "ds-cfg-instance-name: " "${_configLDIF}" | awk -F": " '{ print $2 }'
    else
        getHostName # simply using the hostname utility does not work on all distros
    fi
}

getFirstHostInTopology() {
    PRODUCT="${1}"
    if test -z "${PRODUCT}"; then
        PRODUCT=DIRECTORY
    fi
    jq -r ".|[.serverInstances[]|select(.product==\"${PRODUCT}\")]|.[0]|.hostname" < "${TOPOLOGY_FILE}"
}

getIP() {
    getent hosts "${1}" 2> /dev/null | awk '{print $1}'
}

getIPsForDomain() {
    getent ahosts "${1}" | grep STREAM | awk '{print $1}'
}

# Loops until a specific ldap host, port, baseDN can be returned successfully
# If it doesn't respond after 8 iterations, then echo the messages passed
#
# parameters:  $1 - hostname
#              $2 - port
#              $3 - baseDN
waitUntilLdapUp() {
    _iCnt=1
    LDAP_UP_TIMEOUT_SECONDS=${LDAP_UP_TIMEOUT_SECONDS:-3600}
    LDAPSEARCH_TIMEOUT_SECONDS=${LDAPSEARCH_TIMEOUT_SECONDS:-12}
    _startTime="$(now)"

    while true; do
        if test "${FIPS_MODE_ON}" = "true"; then
            if test "$(cat /proc/sys/kernel/random/entropy_avail)" -lt 100; then
                echo_red "Your entropy pool is very low."
                echo_red "Please install the rngd daemon or a hardware RNG on the node"
                # the entropy is likely too low to attempt a full on TLS handshake
                # if we did, we'd deplete the entropy pool and further slow down
                # server setup, import, dsconfig, startup or replication enablement
                timeout "${LDAPSEARCH_TIMEOUT_SECONDS}" nc -z "${1}" "${2}" > /dev/null 2>&1 && break
                # sleep long enough to give the entropy pool a shot at refilling
                sleep 151
            else
                # the entropy is sufficient to attempt a full on TLS handshake
                # this is the better option to test that the server indeed serves data
                # we're more lenient on timeout than in normal mode
                timeout "${LDAPSEARCH_TIMEOUT_SECONDS}" ldapsearch \
                    --terse \
                    --suppressPropertiesFileComment \
                    --hostname "${1}" \
                    --port "${2}" \
                    --useSSL \
                    --trustAll \
                    --baseDN "${3}" \
                    --scope base "(&)" 1.1 2> /dev/null && break
                # we avoid using a random if we don't have to in FIPS mode
                sleep 15
            fi
        else
            timeout "${LDAPSEARCH_TIMEOUT_SECONDS}" ldapsearch \
                --terse \
                --suppressPropertiesFileComment \
                --hostname "${1}" \
                --port "${2}" \
                --useSSL \
                --trustAll \
                --baseDN "${3}" \
                --scope base "(&)" 1.1 2> /dev/null
            test ${?} -eq 0 && return 0
            sleep_at_most 15
        fi

        if test ${_iCnt} -eq 8; then
            _iCnt=0
            echo "May be a DNS/Firewall/Service/PortMapping Issue."
            echo "    Ensure that the container/pod can reach: ${1}:${2}"
        fi

        _iCnt=$((_iCnt + 1))
        _thisIteration="$(now)"
        if test $((_thisIteration - _startTime)) -gt "${LDAP_UP_TIMEOUT_SECONDS}"; then
            echo_red "We waited for LDAP to come up for more than ${LDAP_UP_TIMEOUT_SECONDS} seconds. Bailing..."
            exit 91
        fi
    done
}

# Print the product version constructed by fields in build-info.txt
# from stdin.
#
# Usage:
#   > cat build-info.txt | build_info_version
#   8.1.0.0-GA
#
build_info_version() {
    awk \
        'BEGIN {maj=0;min=0;pt=0;patch=0;qal=""}
$1=="Major" {maj=$3}
$1=="Minor" {min=$3}
$1=="Point" {pt=$3}
$1=="Patch" {patch=$3}
$2=="Qualifier:" && $3~/^-[A-Z0-9]+$/ {qal=$3}
$2=="Qualifier:" && $3~/^[A-Z0-9]+$/ {qal="-" $3}
$2=="Number:" && $3~/-GA$/ {qal="-GA"}
END {print maj "." min "." pt "." patch qal}'
}

# Convert a PingData version from stdin to a version string that can be
# compared. The qualifier is converted to a numeric value, and the interior
# version segments are left zero-padded. As an example,
# 8.2.0.0-GA is converted to 80200002.
#
# TODO: Somehow differentiate between product SNAPSHOTs of EA and GA builds.
# The current logic considers all SNAPSHOTs to be ordered before EA builds, when
# GA SNAPSHOTs should be ordered after EA.
#
# Qualifiers:
#     -GA  - 3
#     -RCn - 2
#     -EA  - 1
#   Other  - 0
#
# Usage:
#   > echo "8.2.0.0-EA" | sortable_version
#   802000001
#
sortable_version() {
    awk \
        'BEGIN {FS="[.-]";qal=0}
$5=="EA" {qal=1}
$5~/^RC[0-9]*$/ {qal=2}
$5=="GA" {qal=3}
END { printf "%d%02d%02d%02d%d",$1,$2,$3,$4,qal }'
}

# Check if the version argument (e.g. "8.1.0.0-GA")
# is equal to the build version.
#
# Usage:
#   > is_version_eq "8.1.0.0-GA"
#   > echo "${?}"
#   1
#
# @param $1 A version string to compare.
#
is_version_eq() {
    _build_info_version=$(build_info_version < "${SERVER_ROOT_DIR}"/build-info.txt |
        sortable_version)
    _sortable_version=$(echo "${1}" | sortable_version)
    test "${_build_info_version}" = "${_sortable_version}"
}

# Check if the version argument (e.g. "8.2.0.0-GA")
# is greater than the build version. SNAPSHOT versions
# without qualifiers (or any qualifier besides "-EA", "-RCn"
# or "-GA") are ordered before "-EA" builds, which are
# ordered before "-RCn", which are before "-GA" builds.
#
# Usage:
#   > is_version_gt "8.2.0.0-EA"
#   > echo "${?}"
#   0
#
# @param $1 A version string to compare.
#
is_version_gt() {
    _build_info_version=$(build_info_version < "${SERVER_ROOT_DIR}"/build-info.txt | sortable_version)
    _sortable_version=$(echo "${1}" | sortable_version)
    test "${_build_info_version}" -gt "${_sortable_version}"
}

# Check if the version argument (e.g. "8.2.0.0")
# is greater than or equal to the build version.
# SNAPSHOT versions without qualifiers (or any qualifier besides
# "-EA", "-RCn", or "-GA") are ordered before "-EA" builds, which are
# ordered before "-RCn", which are before "-GA" builds.
#
# Usage:
#   > is_version_ge "8.2.0.0-EA"
#   > echo "${?}"
#   1
#
# @param $1 A version string to compare.
#
is_version_ge() {
    is_version_eq "${1}" || is_version_gt "${1}"
}

# Build environment variables needed for starting up the container and joining a
# topology, and print out the resulting plan.
# The run plan is based on what is orchestrating the containers (kubernetes, docker-compose, etc.).
# Orchestration is necessary for containers to find a seed server to join a topology with.
# Needed for PingDirectory replication setup and PingDataSync failover setup.
buildRunPlan() {
    # Create temporary files that will be used to store output as items are determined
    _fullPlan=$(mktemp)
    _planSteps=$(mktemp)
    ORCHESTRATION_TYPE=$(echo "${ORCHESTRATION_TYPE}" | tr '[:lower:]' '[:upper:]')

    # Goal of building a run plan is to provide a plan for the server as it starts up
    # Options for the RUN_PLAN and the PD_STATE are as follows:
    #
    # RUN_PLAN (Initially set to UNKNOWN)
    #          START   - Instructs the container to start from scratch.  This is primarily
    #                    because a server.uuid file is not present.
    #          RESTART - Instructs the container to restart an existing instance.  This is
    #                    primarily because an existing server.uuid file is present.
    #
    # PD_STATE (Initially set to UNKNOWN)
    #          SETUP   - Specifies that the server should be setup
    #          RESTART - Specifies that the server should be restarted
    #          UPDATE  - Specifies that the server should be updated
    #          GENESIS - A very special case when the server is determined to be the
    #                    SEED Server and initial server should be setup and data imported
    RUN_PLAN="UNKNOWN"
    PD_STATE="UNKNOWN"
    SERVER_UUID_FILE="${SERVER_ROOT_DIR}/config/server.uuid"

    # If we have a server.uuid file, then the container should RESTART with an UPDATE plan for
    # PingDirectory, and a RESTART plan for any other PingData products.
    # If we don't have a server.uuid file, then we should START with a SETUP plan.  Additionally
    #    if a SERVER_ROOT_DIR is found, then we should cleanup before starting.
    if test -f "${SERVER_UUID_FILE}"; then

        # Sets the serverUUID variable
        # shellcheck disable=SC1090
        . "${SERVER_UUID_FILE}"

        RUN_PLAN="RESTART"
        if test "${PING_PRODUCT}" = "PingDirectory"; then
            PD_STATE="UPDATE"
        else
            PD_STATE="RESTART"
        fi
    else
        RUN_PLAN="START"
        PD_STATE="SETUP"

        if test -d "${SERVER_ROOT_DIR}"; then
            echo "No server.uuid found. Removing existing SERVER_ROOT_DIR '${SERVER_ROOT_DIR}''"
            rm -rf "${SERVER_ROOT_DIR}"
        fi
    fi

    #
    # Create all the POD Server details
    #
    _podName=$(getHostName)
    _ordinal="${_podName##*-}"

    _podInstanceName=$(getPingDataInstanceName)
    POD_HOSTNAME="${_podInstanceName}"

    _podLocation="${LOCATION}"
    POD_LDAPS_PORT="${LDAPS_PORT}"
    if test "${PING_PRODUCT}" = "PingDirectory"; then
        _podReplicationPort="${REPLICATION_PORT}"
    fi

    # The variable $serverUUID is set when $SERVER_UUID_FILE is sourced.
    # shellcheck disable=SC2154
    echo "
    ###################################################################################
    #            ORCHESTRATION_TYPE: ${ORCHESTRATION_TYPE}
    #                      HOST_NAME: ${HOST_NAME}
    #                    serverUUID: ${serverUUID}
    #" >> "${_planSteps}"

    #########################################################################
    # KUBERNETES ORCHESTRATION_TYPE
    #########################################################################
    if test "${ORCHESTRATION_TYPE}" = "KUBERNETES"; then

        if test -z "${K8S_STATEFUL_SET_NAME}"; then
            container_failure "03" "KUBERNETES Orchestration ==> K8S_STATEFUL_SET_NAME required"
        fi

        if test -z "${K8S_STATEFUL_SET_SERVICE_NAME}"; then
            container_failure "03" "KUBERNETES Orchestration ==> K8S_STATEFUL_SET_SERVICE_NAME required"
        fi

        #
        # Check to see if we have the variables for single or multi cluster topology
        #
        # If we have both K8S_CLUSTER and K8S_SEED_CLUSTER defined then we are in a
        # multi cluster mode.
        #
        if test -z "${K8S_CLUSTERS}" ||
            test -z "${K8S_CLUSTER}" ||
            test -z "${K8S_SEED_CLUSTER}"; then
            _clusterMode="single"

            if test ! -z "${K8S_CLUSTERS}" ||
                test ! -z "${K8S_CLUSTER}" ||
                test ! -z "${K8S_SEED_CLUSTER}"; then
                echo "One of K8S_CLUSTERS (${K8S_CLUSTERS}), K8S_CLUSTER (${K8S_CLUSTER}), K8S_SEED_CLUSTER (${K8S_SEED_CLUSTER}) aren't set."
                echo "All or none of these must be set."
                container_failure "03" "KUBERNETES Orchestration ==> All or none of K8S_CLUSTERS K8S_CLUSTER K8S_SEED_CLUSTER required"
            fi
        else
            _clusterMode="multi"

            if test -z "${K8S_POD_HOSTNAME_PREFIX}"; then
                echo "K8S_POD_HOSTNAME_PREFIX not set.  Defaulting to K8S_STATEFUL_SET_NAME- (\${K8S_STATEFUL_SET_NAME}-)"
                K8S_POD_HOSTNAME_PREFIX="${K8S_STATEFUL_SET_NAME}-"
            fi

            if test -z "${K8S_POD_HOSTNAME_SUFFIX}"; then
                echo "K8S_POD_HOSTNAME_SUFFIX not set.  Defaulting to K8S_CLUSTER (.\${K8S_CLUSTER})"
                K8S_POD_HOSTNAME_SUFFIX=".\${K8S_CLUSTER}"
            fi

            if test -z "${K8S_SEED_HOSTNAME_PREFIX}"; then
                echo "K8S_SEED_HOSTNAME_PREFIX not set.  Defaulting to K8S_POD_HOSTNAME_PREFIX (\${K8S_POD_HOSTNAME_PREFIX})"
                K8S_SEED_HOSTNAME_PREFIX="${K8S_POD_HOSTNAME_PREFIX}"
            fi

            if test -z "${K8S_SEED_HOSTNAME_SUFFIX}"; then
                echo "K8S_SEED_HOSTNAME_SUFFIX not set.  Defaulting to K8S_SEED_CLUSTER (.\${K8S_SEED_CLUSTER})"
                K8S_SEED_HOSTNAME_SUFFIX=".\${K8S_SEED_CLUSTER}"
            fi

            if test "${K8S_INCREMENT_PORTS}" = true; then
                _incrementPortsMsg="Using different ports for each instance, incremented from LDAPS_PORT (${LDAPS_PORT})"
                if test "${PING_PRODUCT}" = "PingDirectory"; then
                    _incrementPortsMsg="${_incrementPortsMsg} and REPLICATION_PORT (${REPLICATION_PORT})"
                fi
            else
                _incrementPortsMsg="K8S_INCREMENT_PORTS not used ==> Using same ports for all instances - LDAPS_PORT (${LDAPS_PORT})"
                if test "${PING_PRODUCT}" = "PingDirectory"; then
                    _incrementPortsMsg="${_incrementPortsMsg}, REPLICATION_PORT (${REPLICATION_PORT})"
                fi
            fi
        fi

        SEED_LDAPS_PORT="${LDAPS_PORT}"
        if test "${PING_PRODUCT}" = "PingDirectory"; then
            _seedReplicationPort="${REPLICATION_PORT}"
        fi

        #
        # Single Cluster Details
        #
        # Create an instance/hostname using the Kubernetes StatefulSet Name and Service Name
        if test "${_clusterMode}" = "single"; then
            _podInstanceName="${K8S_STATEFUL_SET_NAME}-${_ordinal}.${K8S_STATEFUL_SET_SERVICE_NAME}"
            POD_HOSTNAME=${_podInstanceName}
            _podLocation="${LOCATION}"

            _seedInstanceName="${K8S_STATEFUL_SET_NAME}-0.${K8S_STATEFUL_SET_SERVICE_NAME}"
            SEED_HOSTNAME=${_seedInstanceName}
            _seedLocation="${LOCATION}"
        fi

        #
        # Multi Cluster Details
        #
        # Create an instance/hostname using the Kubernetes Cluster and Suffixes provided
        if test "${_clusterMode}" = "multi"; then
            _podInstanceName="${K8S_STATEFUL_SET_NAME}-${_ordinal}.${K8S_CLUSTER}"
            POD_HOSTNAME=$(eval "echo ${K8S_POD_HOSTNAME_PREFIX}${_ordinal}${K8S_POD_HOSTNAME_SUFFIX}")
            _podLocation="${K8S_CLUSTER}"

            if test -n "${RESTRICTED_BASE_DNS}" && test "${K8S_CLUSTER}" != "${K8S_SEED_CLUSTER}" && test "${_ordinal}" != "0"; then
                # Use the 0-ordinal server of this cluster as the initialize source when using entry balancing.
                # If we are within the seed cluster, or if we are the 0 ordinal server, this isn't necessary.
                # Shellcheck complains these variables aren't used, but they are exported below
                # shellcheck disable=SC2034
                INITIALIZE_SOURCE_HOSTNAME=$(eval "echo ${K8S_POD_HOSTNAME_PREFIX}0${K8S_POD_HOSTNAME_SUFFIX}")
                # The 0-ordinal server should have the default LDAPS port even when incrementing ports
                # shellcheck disable=SC2034
                INITIALIZE_SOURCE_LDAPS_PORT="${LDAPS_PORT}"
            fi

            _seedInstanceName="${K8S_STATEFUL_SET_NAME}-0.${K8S_SEED_CLUSTER}"
            SEED_HOSTNAME=$(eval "echo ${K8S_SEED_HOSTNAME_PREFIX}0${K8S_SEED_HOSTNAME_SUFFIX}")
            _seedLocation="${K8S_SEED_CLUSTER}"

            if test "${K8S_INCREMENT_PORTS}" = "true"; then
                POD_LDAPS_PORT=$((LDAPS_PORT + _ordinal))
                LDAPS_PORT=${POD_LDAPS_PORT}
                if test "${PING_PRODUCT}" = "PingDirectory"; then
                    _podReplicationPort=$((REPLICATION_PORT + _ordinal))
                    REPLICATION_PORT=${_podReplicationPort}
                fi
            fi
        fi

        if test "${_podInstanceName}" = "${_seedInstanceName}"; then
            echo "We are the SEED server (${_seedInstanceName})"
            # Create a marker file to indicate that this is the seed server
            touch /tmp/seed-server

            if test -z "${serverUUID}"; then
                if test "$(toLower "${PARALLEL_POD_MANAGEMENT_POLICY}")" = "true"; then
                    # When starting up pods with the Parallel podManagementPolicy in a
                    # Kubernetes StatefulSet, the seed server has to assume it is in a genesis state,
                    # since there will immediately be multiple pods starting up in the StatefulSet.
                    PD_STATE="GENESIS"
                else
                    #
                    # First, we will check to see if there are any servers available in
                    # existing cluster
                    _numHosts=$(getIPsForDomain "${K8S_STATEFUL_SET_SERVICE_NAME}" | wc -w 2> /dev/null)

                    echo "Number of servers available in this domain: ${_numHosts}"

                    #
                    # If there are no hosts found, this is situation where the k8s service cluster
                    # is returning no hosts, hence, there are no pingdirectory instances running
                    if test "${_numHosts}" -eq 0; then
                        #
                        # Second, we need to check other clusters
                        if test "${_clusterMode}" = "multi"; then
                            echo_red "We need to check all 0 servers in each cluster"
                        fi

                        PD_STATE="GENESIS"
                    fi

                    # Note: Added when headless pingdirectory-cluster support was added for enhancements
                    #       to PingDirectory 8.2
                    #
                    # If there is only 1 host that is returned, and that host's IP is the same
                    # as the current _podHostName, then we can assured that this server is the first
                    # in the current statefulset to be started, and will mark as GENESIS
                    if test "${_numHosts}" -eq 1 && test "$(getIP "${_podName}")" = "$(getIPsForDomain "${K8S_STATEFUL_SET_SERVICE_NAME}")"; then
                        echo "Verified that this host/ip is the only pod found in domain '${K8S_STATEFUL_SET_SERVICE_NAME}'"
                        PD_STATE="GENESIS"
                    fi
                fi
            fi
        fi

        echo "#
    #         K8S_STATEFUL_SET_NAME: ${K8S_STATEFUL_SET_NAME}
    # K8S_STATEFUL_SET_SERVICE_NAME: ${K8S_STATEFUL_SET_SERVICE_NAME}
    #
    #                  K8S_CLUSTERS: ${K8S_CLUSTERS}  (${_clusterMode} cluster)
    #                   K8S_CLUSTER: ${K8S_CLUSTER}
    #              K8S_SEED_CLUSTER: ${K8S_SEED_CLUSTER}
    #              K8S_NUM_REPLICAS: ${K8S_NUM_REPLICAS}
    #       K8S_POD_HOSTNAME_PREFIX: ${K8S_POD_HOSTNAME_PREFIX}
    #       K8S_POD_HOSTNAME_SUFFIX: ${K8S_POD_HOSTNAME_SUFFIX}
    #      K8S_SEED_HOSTNAME_PREFIX: ${K8S_SEED_HOSTNAME_PREFIX}
    #      K8S_SEED_HOSTNAME_SUFFIX: ${K8S_SEED_HOSTNAME_SUFFIX}
    #           K8S_INCREMENT_PORTS: ${K8S_INCREMENT_PORTS} (${_incrementPortsMsg})
    #
    #" >> "${_planSteps}"

    fi

    #########################################################################
    # COMPOSE ORCHESTRATION_TYPE
    #########################################################################
    if test "${ORCHESTRATION_TYPE}" = "COMPOSE"; then
        # Assume GENESIS state for now, if we aren't kubernetes when setting up
        if test "${RUN_PLAN}" = "START"; then
            PD_STATE="GENESIS"

            #
            # Check to see
            if test "$(getIP "${COMPOSE_SERVICE_NAME}_1")" != "$(getIP "${HOST_NAME}")"; then
                echo "We are the SEED Server"
                PD_STATE="SETUP"
            fi
        fi

        if test -z "${COMPOSE_SERVICE_NAME}"; then
            if test "${PING_PRODUCT}" = "PingDirectory"; then
                echo "Replication will not be enabled."
                echo "Variable COMPOSE_SERVICE_NAME is required to enable replication."
            else
                echo "Sync failover will not be enabled."
                echo "Variable COMPOSE_SERVICE_NAME is required to enable failover."
            fi
        else
            SEED_HOSTNAME="${COMPOSE_SERVICE_NAME}_1"
            _seedInstanceName="${COMPOSE_SERVICE_NAME}"
            _seedLocation="${LOCATION}"
            SEED_LDAPS_PORT="${LDAPS_PORT}"
            if test "${PING_PRODUCT}" = "PingDirectory"; then
                _seedReplicationPort="${REPLICATION_PORT}"
            fi
        fi
    fi

    #########################################################################
    # DIRECTED ORCHESTRATION_TYPE
    #########################################################################
    if test "${ORCHESTRATION_TYPE}" = "DIRECTED"; then
        if test "${RUN_PLAN}" = "START"; then
            # When the RUN_PLAN is for a fresh start (vs a restart of a container)
            if test -z "${REPLICATION_SEED_HOST}" && test -z "${FAILOVER_SEED_HOST}"; then
                # either it is a genesis event for a standalone container
                # or the first container of a topology
                PD_STATE="GENESIS"
            else
                # OR the container is directed to join a topology from a seed host
                PD_STATE="SETUP"
            fi
        fi

        if test "${PING_PRODUCT}" = "PingDirectory"; then
            SEED_HOSTNAME="${REPLICATION_SEED_HOST}"
            _seedInstanceName="${REPLICATION_SEED_NAME:-${REPLICATION_SEED_HOST}}"
            _seedLocation="${REPLICATION_SEED_LOCATION:-${LOCATION}}"
            SEED_LDAPS_PORT="${REPLICATION_SEED_LDAPS_PORT:-${LDAPS_PORT}}"
            _seedReplicationPort="${REPLICATION_SEED_REPLICATION_PORT:-${REPLICATION_PORT}}"
        else
            SEED_HOSTNAME="${FAILOVER_SEED_HOST}"
            _seedInstanceName="${FAILOVER_SEED_NAME:-${FAILOVER_SEED_HOST}}"
            _seedLocation="${FAILOVER_SEED_LOCATION:-${LOCATION}}"
            SEED_LDAPS_PORT="${FAILOVER_SEED_LDAPS_PORT:-${LDAPS_PORT}}"
        fi
    fi

    #########################################################################
    # Unknown ORCHESTRATION_TYPE
    #########################################################################
    if test -z "${ORCHESTRATION_TYPE}" && test "${PD_STATE}" = "SETUP"; then
        if test "${PING_PRODUCT}" = "PingDirectory"; then
            echo "Replication will not be enabled. Unknown ORCHESTRATION_TYPE"
        else
            echo "Sync failover will not be enabled. Unknown ORCHESTRATION_TYPE"
        fi
        PD_STATE="GENESIS"
    fi

    #
    # Print out different messages/startup plans based on the PD_STATE
    # If the PD_STATE is not set to a known state, then we have a container failure
    #
    case "${PD_STATE}" in
        GENESIS)
            echo "\
    #     Startup Plan
    #        - manage-profile setup" >> "${_planSteps}"
            if test "${PING_PRODUCT}" = "PingDirectory"; then
                echo "\
    #        - import data" >> "${_planSteps}"
            fi

            echo "
    ##################################################################################
    #
    #                                   IMPORTANT MESSAGE
    #
    #                                  GENESIS STATE FOUND
    #
    # If it is suspected that we shouldn't be in the GENESIS state, take actions to
    # remediate.
    #
    # Based on the following information, we have determined that we are the SEED server
    # in the GENESIS state (First server to come up in this stateful set) due to the
    # following conditions:
    #
    #   1. We couldn't find a valid server.uuid file"

            test "${ORCHESTRATION_TYPE}" = "KUBERNETES" && echo "\
    #
    #   2. KUBERNETES - Our host name ($(hostname))is the 1st one in the stateful set (${K8S_STATEFUL_SET_SERVICE_NAME}-0)
    #   3. KUBERNETES - There are no other servers currently running in the stateful set (${K8S_STATEFUL_SET_SERVICE_NAME}),
    #                   or the stateful set is configured to start up pods in parallel"

            test "${ORCHESTRATION_TYPE}" = "COMPOSE" && echo "\
    #
    #   2. COMPOSE - Our host name ($(hostname)) has the same IP address as the
                    first host in the COMPOSE_SERVICE_NAME (${COMPOSE_SERVICE_NAME}_1)"
            echo "\
    #
    ##################################################################################
    "
            ;;
        SETUP)
            echo "\
    #     Startup Plan
    #        - manage-profile setup" >> "${_planSteps}"
            if test "${PING_PRODUCT}" = "PingDirectory"; then
                echo "\
    #        - repl enable (from SEED Server-${_seedInstanceName})
    #        - repl init   (from topology.json, from SEED Server-${_seedInstanceName})" >> "${_planSteps}"
            else
                echo "\
    #        - manage-topology add-server (from SEED Server-${_seedInstanceName})" >> "${_planSteps}"
            fi
            ;;
        UPDATE)
            echo "\
    #     Startup Plan
    #        - manage-profile replace-profile" >> "${_planSteps}"
            if test "${PING_PRODUCT}" = "PingDirectory"; then
                echo "\
    #        - repl enable (from SEED Server-${_seedInstanceName})
    #        - repl init   (from topology.json, from SEED Server-${_seedInstanceName})" >> "${_planSteps}"
            fi
            ;;
        RESTART)
            echo "\
    #     Startup Plan
    #        - start-server" >> "${_planSteps}"
            ;;
        *)
            container_failure 08 "Unknown PD_STATE of ($PD_STATE)"
            ;;
    esac

    {
        echo "
    ###################################################################################
    #
    #                      PD_STATE: ${PD_STATE}
    #                      RUN_PLAN: ${RUN_PLAN}
    #"

        cat "${_planSteps}"
    } >> "${_fullPlan}"

    echo "\
    ###################################################################################
    #
    # POD Server Information
    #                 instance name: ${_podInstanceName}
    #                      hostname: ${POD_HOSTNAME}
    #                      location: ${_podLocation}
    #                    ldaps port: ${POD_LDAPS_PORT}" >> "${_fullPlan}"
    if test "${PING_PRODUCT}" = "PingDirectory"; then
        echo "\
    #              replication port: ${_podReplicationPort}" >> "${_fullPlan}"
    fi
    echo "\
    #
    # SEED Server Information
    #                 instance name: ${_seedInstanceName}
    #                      hostname: ${SEED_HOSTNAME}
    #                      location: ${_seedLocation}
    #                    ldaps port: ${SEED_LDAPS_PORT}" >> "${_fullPlan}"
    if test "${PING_PRODUCT}" = "PingDirectory"; then
        echo "\
    #              replication port: ${_seedReplicationPort}" >> "${_fullPlan}"
    fi
    echo "\
    ###################################################################################
    " >> "${_fullPlan}"

    #########################################################################
    # print out a table of all the pods and clusters if we have the proper variables
    # defined
    #########################################################################
    if test ! -z "${K8S_CLUSTERS}" &&
        test ! -z "${K8S_NUM_REPLICAS}"; then
        _numReplicas=${K8S_NUM_REPLICAS}
        _clusterWidth=0
        _podWidth=0
        _portWidth=5

        #
        # First, we will calculate a bunch of sizes so we can print in a pretty table
        # and place all the values into a row array to be printed in a loop later on
        #
        for _cluster in ${K8S_CLUSTERS}; do
            # get the max size of cluster name
            test "${#_cluster}" -gt "${_clusterWidth}" && _clusterWidth=${#_cluster}

            i=0
            while test $i -lt "${_numReplicas}"; do
                _pod="${K8S_STATEFUL_SET_NAME}-${_ordinal}.${_cluster}"

                # get the max size of the pod name
                test "${#_pod}" -gt "${_podWidth}" && _podWidth=${#_pod}

                _ldapsPort=${SEED_LDAPS_PORT}
                if test "${PING_PRODUCT}" = "PingDirectory"; then
                    _replicationPort=${_seedReplicationPort}
                fi
                if test "${K8S_INCREMENT_PORTS}" = true; then
                    _ldapsPort=$((_ldapsPort + i))
                    if test "${PING_PRODUCT}" = "PingDirectory"; then
                        _replicationPort=$((_replicationPort + i))
                    fi
                fi

                i=$((i + 1))
            done
        done

        # Get the total width of each row and the width of the cluster header rows
        if test "${PING_PRODUCT}" = "PingDirectory"; then
            # pingdirectory needs an extra column for the replication port
            totalWidth=$((_podWidth + _portWidth + _portWidth + 11))
        else
            totalWidth=$((_podWidth + _portWidth + 11))
        fi
        _clusterWidth=$((totalWidth - 14))

        # The following are some variables used for printf format statements
        _dashes="--------------------------------------------------------------------------------"
        _clusterFormat="# | %-4s   %-4s | CLUSTER: %-${_clusterWidth}s |\n"
        if test "${PING_PRODUCT}" = "PingDirectory"; then
            _separatorRow=$(printf "# +------+------+-%.${_podWidth}s-+-%.${_portWidth}s-+-%.${_portWidth}s-+\n" \
                "${_dashes}" "${_dashes}" "${_dashes}")
            _podFormat="# | %-4s | %-4s | %-${_podWidth}s | %-${_portWidth}s | %-${_portWidth}s |\n"
        else
            _separatorRow=$(printf "# +------+------+-%.${_podWidth}s-+-%.${_portWidth}s-+\n" \
                "${_dashes}" "${_dashes}" "${_dashes}")
            _podFormat="# | %-4s | %-4s | %-${_podWidth}s | %-${_portWidth}s |\n"
        fi

        # print out the top header for the table
        echo "${_separatorRow}" >> "${_fullPlan}"
        if test "${PING_PRODUCT}" = "PingDirectory"; then
            # shellcheck disable=SC2059
            printf "${_podFormat}" "SEED" "POD" "Instance" "LDAPS" "REPL" >> "${_fullPlan}"
        else
            # shellcheck disable=SC2059
            printf "${_podFormat}" "SEED" "POD" "Instance" "LDAPS" >> "${_fullPlan}"
        fi

        # Print each row
        for _cluster in ${K8S_CLUSTERS}; do
            _ordinal=0

            while test $_ordinal -lt "${_numReplicas}"; do
                _pod="${K8S_STATEFUL_SET_NAME}-${_ordinal}.${_cluster}"

                # If we are printing a row representing the seed pod
                _seedIndicator=""
                test "${_cluster}" = "${K8S_SEED_CLUSTER}" &&
                    test "${_ordinal}" = "0" &&
                    _seedIndicator="***"

                # If we are printing a row representing the current pod, then we will
                # provide an indicator of that
                _podIndicator=""
                test "${_podInstanceName}" = "${_pod}" && _podIndicator="***"

                _ldapsPort=${LDAPS_PORT}
                if test "${PING_PRODUCT}" = "PingDirectory"; then
                    _replicationPort=${REPLICATION_PORT}
                fi
                if test "${K8S_INCREMENT_PORTS}" = true; then
                    _ldapsPort=$((_ldapsPort + _ordinal))
                    if test "${PING_PRODUCT}" = "PingDirectory"; then
                        _replicationPort=$((_replicationPort + _ordinal))
                    fi
                fi

                # As we print the rows, if we are a new cluster, then we'll print a new cluster
                # header row
                if test "${_prevCluster}" != "${_cluster}"; then
                    {
                        echo "${_separatorRow}"
                        # shellcheck disable=SC2059
                        printf "${_clusterFormat}" "${_seedIndicator}" "" "${_cluster}"
                        echo "${_separatorRow}"
                    } >> "${_fullPlan}"
                fi
                _prevCluster=${_cluster}

                if test "${PING_PRODUCT}" = "PingDirectory"; then
                    # shellcheck disable=SC2059
                    printf "${_podFormat}" "${_seedIndicator}" "${_podIndicator}" "${_pod}" "${_ldapsPort}" "${_replicationPort}" >> "${_fullPlan}"
                else
                    # shellcheck disable=SC2059
                    printf "${_podFormat}" "${_seedIndicator}" "${_podIndicator}" "${_pod}" "${_ldapsPort}" >> "${_fullPlan}"
                fi

                _ordinal=$((_ordinal + 1))
            done
        done

        echo "${_separatorRow}" >> "${_fullPlan}"
    fi

    # Print out the full plan
    cat "${_fullPlan}"

    INSTANCE_NAME=${_podInstanceName}
    LOCATION=${_podLocation}

    # next line is for shellcheck disable to ensure $RUN_PLAN is used
    echo "${INSTANCE_NAME}" >> /dev/null

    # PingData Orchestration info
    export_container_env ORCHESTRATION_TYPE RUN_PLAN PD_STATE INSTANCE_NAME

    # POD Server Info
    export_container_env _podInstanceName POD_HOSTNAME _podLocation POD_LDAPS_PORT
    if test "${PING_PRODUCT}" = "PingDirectory"; then
        export_container_env _podReplicationPort
    fi

    # SEED Server Info
    export_container_env _seedInstanceName SEED_HOSTNAME _seedLocation SEED_LDAPS_PORT
    if test "${PING_PRODUCT}" = "PingDirectory"; then
        export_container_env _seedReplicationPort
    fi

    # PingData Port Info
    export_container_env LDAPS_PORT LOCATION
    if test "${PING_PRODUCT}" = "PingDirectory"; then
        export_container_env REPLICATION_PORT
    fi

    # Entry balancing info for PingDirectory
    if test "${PING_PRODUCT}" = "PingDirectory" && test -n "${RESTRICTED_BASE_DNS}"; then
        export_container_env INITIALIZE_SOURCE_HOSTNAME INITIALIZE_SOURCE_LDAPS_PORT
    fi

    # Cleanup Temp Files
    rm -f "${_fullPlan} ${_planSteps}"
}

# Wait for the seed server and ensure all variables are set for this server
# to join a topology for replication (PingDirectory) or failover (PingDataSync).
#
# This method returns 0 if the server was successfully prepared and should move
# forward with joining the topology. It will return a non-zero exit code if the
# server should not attempt to join the topology.
prepareToJoinTopology() {
    #
    #- * Ensures the PingData service has been started and accepts queries.
    #
    _podName=$(getHostName)
    _ordinal="${_podName##*-}"
    echo "Waiting until ${PING_PRODUCT} service is running on this Server (${_podInstanceName:?})"
    echo "        ${_podName:?}:${POD_LDAPS_PORT:?}"

    waitUntilLdapUp "${_podName}" "${POD_LDAPS_PORT}" ""

    if ! test "$(toLower "${SKIP_WAIT_FOR_DNS}")" = "true"; then
        if test "${ORCHESTRATION_TYPE}" = "KUBERNETES" && test -n "${K8S_POD_HOSTNAME_PREFIX}" && test -n "${K8S_POD_HOSTNAME_SUFFIX}"; then
            waitForDns "${WAIT_FOR_DNS_TIMEOUT:-600}" "${K8S_POD_HOSTNAME_PREFIX}${_ordinal}${K8S_POD_HOSTNAME_SUFFIX}"
        fi
    fi

    #
    #- * Only version 8.2-EA and greater support configuring sync failover
    #
    if test "${PING_PRODUCT}" = "PingDataSync" && ! is_version_ge "8.2.0.0-EA"; then
        echo "PingDataSync failover will not be configured. Product version older than 8.2.0.0-EA."
        return 1
    fi

    #
    #- * Updates the Server Instance hostname/ldaps-port
    #
    echo "Updating the Server Instance hostname/ldaps-port:
            instance: ${_podInstanceName}
            hostname: ${POD_HOSTNAME}
        ldaps-port: ${POD_LDAPS_PORT}"

    dsconfig set-server-instance-prop --no-prompt --quiet \
        --instance-name "${_podInstanceName}" \
        --set hostname:"${POD_HOSTNAME}" \
        --set ldaps-port:"${POD_LDAPS_PORT}"

    _updateServerInstanceResult=$?
    echo "Updating the Server Instance ${_podInstanceName} result=${_updateServerInstanceResult}"

    #
    #- * Check to see if PD_STATE is GENESIS.  If so, no replication or failover will be performed
    #
    if test "${PD_STATE}" = "GENESIS"; then
        if test "${PING_PRODUCT}" = "PingDirectory"; then
            echo "PD_STATE is GENESIS ==> Replication on this server won't be set up until more instances are added"
        else
            echo "PD_STATE is GENESIS ==> Failover on this server won't be set up until more instances are added"
        fi
        return 1
    fi

    if test -z "${_seedInstanceName}" || test -z "${SEED_HOSTNAME}" || test -z "${SEED_LDAPS_PORT}"; then
        if test "${PING_PRODUCT}" = "PingDirectory"; then
            echo "PingDirectory replication will not be configured. Seed server could not be determined."
        else
            echo "PingDataSync failover will not be configured. Seed server could not be determined."
        fi
        return 1
    fi

    #Change the seed build out for pingDirectory-0 server that has been restarted and it's pvc lost
    if test "${_podInstanceName}" = "${_seedInstanceName}" &&
        test "${PD_STATE}" = "SETUP" && test "${ORCHESTRATION_TYPE}" = "KUBERNETES"; then
        #TODO: GDO-997 multi-region may need to look for local cluster OR remote cluster for a seed.
        _IPList=$(getIPsForDomain "${K8S_STATEFUL_SET_SERVICE_NAME}")
        for ip in ${_IPList}; do
            if test "$(getIP "${POD_HOSTNAME}")" != "${ip}"; then
                SEED_HOSTNAME=${ip}
                _seedInstanceName=${ip}
                waitUntilLdapUp "${SEED_HOSTNAME}" "${SEED_LDAPS_PORT}" "" > /dev/null 2>&1
                echo_yellow "This seed server is out of sync with the topology. Using alternative seed server: ${SEED_HOSTNAME}:${SEED_LDAPS_PORT}"
                export_container_env _seedInstanceName SEED_HOSTNAME
                break
            fi
        done
    fi

    #
    #- * Ensure the Seed Server is accepting queries
    #
    echo "Running ldapsearch test on SEED Server (${_seedInstanceName:?})"
    echo "        ${SEED_HOSTNAME:?}:${SEED_LDAPS_PORT:?}"
    waitUntilLdapUp "${SEED_HOSTNAME}" "${SEED_LDAPS_PORT}" ""

    #
    #- * Check the topology prior to enabling replication or failover
    #
    _priorTopoFile="/tmp/priorTopology.json"
    rm -rf "${_priorTopoFile}"
    manage-topology export \
        --hostname "${SEED_HOSTNAME}" \
        --port "${SEED_LDAPS_PORT}" \
        --exportFilePath "${_priorTopoFile}"
    _priorNumInstances=$(jq ".serverInstances | length" "${_priorTopoFile}")

    #
    #- * If this server is already in a prior topology, then replication or failover may already be enabled.
    #- * It is also possible that this server has lost its volume and isn't aware of the topology.
    #- * When that is the case, run remove-defunct-server and re-add this server to the topology from the seed server.
    #
    if test ! -z "$(jq -r ".serverInstances[] | select(.instanceName==\"${_podInstanceName}\") | .instanceName" "${_priorTopoFile}")"; then
        # Get the topology according to this instance if possible.
        _currentTopoFile="/tmp/currentTopology.json"
        rm -rf "${_currentTopoFile}"
        manage-topology export \
            --hostname "${POD_HOSTNAME}" \
            --port "${POD_LDAPS_PORT}" \
            --exportFilePath "${_currentTopoFile}"
        _returnCode=$?

        # Check if manage-topology was successfull
        if test ${_returnCode} -ne 0; then
            echo_red "**********"
            echo_red "Failed to run the manage-topology tool while setting up the topology"
            echo_red "Container cannot reach itself"
            exit ${_returnCode}
        fi

        # Check if this server knows about the seed server.
        if test -z "$(jq -r ".serverInstances[] | select(.instanceName==\"${_seedInstanceName}\") | .instanceName" "${_currentTopoFile}")"; then
            # If this instance does not think it is in the seed server's topology, then it may have lost its volume.
            # Remove the remnants of this server from the seed server's topology so it can be re-added below.
            echo_yellow "Seed server topology and local topology are out of sync. Running remove-defunct-server before re-adding this server to the topology."
            remove-defunct-server --no-prompt \
                --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
                --topologyFilePath "${_priorTopoFile}" \
                --serverInstanceName "${_podInstanceName}" \
                --ignoreOnline \
                --bindDN "${ROOT_USER_DN}" \
                --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
                --enableDebug --globalDebugLevel verbose
            _returnCode=$?

            if test ${_returnCode} -ne 0; then
                echo_red "**********"
                echo_red "Failed to run the remove-defunct-server tool while setting up the topology"
                echo_red "Contents of remove-defunct-server.log file:"
                cat "${SERVER_ROOT_DIR}"/logs/tools/remove-defunct-server.log
                return ${_returnCode}
            fi
            _priorNumInstances=$((_priorNumInstances - 1))
        else
            # If the server knows about the seed server's topology locally, then everything is good.
            if test "${PING_PRODUCT}" = "PingDirectory"; then
                echo "This instance (${_podInstanceName}) is already found in topology --> No need to enable replication"
                dsreplication status --displayServerTable --showAll
            else
                echo "This instance (${_podInstanceName}) is already found in topology --> No need to enable failover"
            fi
            return 1
        fi
    fi

    #
    #- * If the server being setup is the Seed Instance, then no replication or failover will be performed
    #
    if test "${_podInstanceName}" = "${_seedInstanceName}"; then
        echo ""
        if test "${PING_PRODUCT}" = "PingDirectory"; then
            echo "We are the SEED Server: ${_seedInstanceName} --> No need to enable replication"
        else
            echo "We are the SEED Server: ${_seedInstanceName} --> No need to enable failover"
        fi
        return 1
    fi

    #
    #- * Get the current Topology Master
    #
    MASTER_TOPOLOGY_INSTANCE=$(ldapsearch --hostname "${SEED_HOSTNAME}" --port "${SEED_LDAPS_PORT}" --terse --outputFormat json -b "cn=Mirrored subtree manager for base DN cn_Topology_cn_config,cn=monitor" -s base objectclass=* master-instance-name | jq -r .attributes[].values[])
    MASTER_TOPOLOGY_HOSTNAME="${SEED_HOSTNAME}"
    MASTER_TOPOLOGY_LDAPS_PORT="${SEED_LDAPS_PORT}"
    if test "${PING_PRODUCT}" = "PingDirectory"; then
        MASTER_TOPOLOGY_REPLICATION_PORT="${_seedReplicationPort:?}"
    fi

    #
    #- * Determine the Master Topology server to use to enable with
    #
    if test "${_priorNumInstances}" -eq 1; then
        if test "${PING_PRODUCT}" = "PingDirectory"; then
            echo "Only 1 instance (${MASTER_TOPOLOGY_INSTANCE}) found in current topology.  Adding 1st replica"
        else
            echo "Only 1 instance (${MASTER_TOPOLOGY_INSTANCE}) found in current topology.  Adding 1st failover server"
        fi
    else
        if test "${MASTER_TOPOLOGY_INSTANCE}" = "${_seedInstanceName}"; then
            echo "Seed Instance is the Topology Master Instance"
            MASTER_TOPOLOGY_HOSTNAME="${SEED_HOSTNAME}"
            MASTER_TOPOLOGY_LDAPS_PORT="${SEED_LDAPS_PORT}"
            if test "${PING_PRODUCT}" = "PingDirectory"; then
                MASTER_TOPOLOGY_REPLICATION_PORT="${_seedReplicationPort}"
            fi
        else
            echo "Topology master instance (${MASTER_TOPOLOGY_INSTANCE}) isn't seed instance (${_seedInstanceName})"

            MASTER_TOPOLOGY_HOSTNAME=$(jq -r ".serverInstances[] | select(.instanceName==\"${MASTER_TOPOLOGY_INSTANCE}\") | .hostname" "${_priorTopoFile}")
            MASTER_TOPOLOGY_LDAPS_PORT=$(jq ".serverInstances[] | select(.instanceName==\"${MASTER_TOPOLOGY_INSTANCE}\") | .ldapsPort" "${_priorTopoFile}")
            if test "${PING_PRODUCT}" = "PingDirectory"; then
                MASTER_TOPOLOGY_REPLICATION_PORT=$(jq ".serverInstances[] | select(.instanceName==\"${MASTER_TOPOLOGY_INSTANCE}\") | .replicationPort" "${_priorTopoFile}")
            fi
        fi
    fi

    test -n "${MASTER_TOPOLOGY_HOSTNAME}" && export MASTER_TOPOLOGY_HOSTNAME
    test -n "${MASTER_TOPOLOGY_LDAPS_PORT}" && export MASTER_TOPOLOGY_LDAPS_PORT
    test -n "${MASTER_TOPOLOGY_REPLICATION_PORT}" && export MASTER_TOPOLOGY_REPLICATION_PORT
    test -n "${MASTER_TOPOLOGY_INSTANCE}" && export MASTER_TOPOLOGY_INSTANCE
}

# Call the remove-defunct-server command on this server
removeDefunctServer() {
    # This script will remove the server from the topology for any graceful
    # termination, i.e. scale-down and rolling-update when invoked from a pre-stop
    # hook. Ideally, the server is not removed from the topology in the rolling
    # update case. However, when using an orchestration framework like Kubernetes,
    # the pod that the container is running on has no way of knowing why it's going
    # down unless it can find this information from an external source (e.g. a
    # topology.json file uploaded to an S3 bucket). A topology.json file provided
    # through a config-map mounted volume will not do because that will change the
    # pod spec and re-spin --all-- of the pods unnecessarily, even if the only
    # change to the deployment is a reduced replica count.
    INSTANCE_NAME=$(dsconfig --no-prompt \
        --useSSL --trustAll \
        --hostname "${HOST_NAME}" --port "${LDAPS_PORT}" \
        get-global-configuration-prop \
        --property instance-name \
        --script-friendly |
        awk '{ print $2 }')

    echo "Removing ${HOST_NAME} (instance name: ${INSTANCE_NAME}) from the topology"
    remove-defunct-server --no-prompt \
        --serverInstanceName "${INSTANCE_NAME}" \
        --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
        --ignoreOnline \
        --bindDN "${ROOT_USER_DN}" \
        --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
        --enableDebug --globalDebugLevel verbose
    echo "Server removal exited with return code: $?"
}

# Get dsconfig options, depending if the servers is running or not (offline)
#
# @param ${1} server state ("online" or "offline"). If not specified or not
#             a valid value, then wait-for will be used to determine whether
#             the server is online or not.
#
get_dsconfig_options() {
    case "${1}" in
        online)
            _isOnline=true
            ;;
        offline)
            _isOnline=false
            ;;
        *)
            wait-for "${HOST_NAME}:${LDAPS_PORT}" -t 1 > /dev/null 2> /dev/null
            if test ${?} -eq 0; then
                _isOnline=true
            else
                _isOnline=false
            fi
            ;;
    esac

    if test "${_isOnline}" = "true"; then
        _options="--no-prompt --quiet --noPropertiesFile --hostname ${HOST_NAME} --bindDN \"${ROOT_USER_DN}\" --bindPasswordFile \"${ROOT_USER_PASSWORD_FILE}\" "
        case "${2}" in
            clear)
                _options="${_options} --port ${LDAP_PORT} --useNoSecurity"
                ;;
            *)
                _options="${_options} --port ${LDAPS_PORT}  --useSSL --trustAll"
                ;;
        esac
        echo "${_options}"
    else
        echo "--no-prompt --quiet --offline --noPropertiesFile"
    fi
}

# Set the Availability returned by the server's availability servlets
# to UNAVAILABLE with a custom response message.
#
# @param ${1} custom response message to display in availability servlets.
#
# @param ${2} server state ("online" or "offline"). If not specified or not
#             a valid value, then wait-for will be used to determine whether
#             the server is online or not.
#
set_server_unavailable() {
    _status="${1:=not ready}"

    _jsonMsg="{ \"status\":\"${_status}\", \"source\":\"${0}\", \"updated\":\"$(date)\" }"

    _dsconfigOptions=$(get_dsconfig_options "$2")
    _batchFile=$(mktemp)

    echo "Setting Server to Unavailable - ${_jsonMsg}"

    echo "dsconfig set-http-servlet-extension-prop \\
        --extension-name \"Available or Degraded State\" \\
        --set override-status-code:503 \\
        --set 'additional-response-contents:${_jsonMsg}'

    dsconfig set-http-servlet-extension-prop \\
        --extension-name \"Available State\" \\
        --set override-status-code:503 \\
        --set 'additional-response-contents:${_jsonMsg}'" > "${_batchFile}"

    # Word-split is expected behavior for $_dsconfigOptions. Disable shellcheck.
    # shellcheck disable=SC2086
    eval "dsconfig ${_dsconfigOptions} --batch-file \"${_batchFile}\""
    rm "${_batchFile}"
}

# Set the Availability of the server to AVAILABLE.
#
# @param ${1} server state ("online" or "offline"). If not specified or not
#             a valid value, then wait-for will be used to determine whether
#             the server is online or not.
#
set_server_available() {
    _dsconfigOptions=$(get_dsconfig_options "${1}")
    _batchFile=$(mktemp)

    echo "Setting Server to Available"

    echo "dsconfig set-http-servlet-extension-prop \\
        --extension-name \"Available or Degraded State\" \\
        --reset override-status-code \\
        --reset additional-response-contents

    dsconfig set-http-servlet-extension-prop \\
        --extension-name \"Available State\" \\
        --reset override-status-code \\
        --reset additional-response-contents" > "${_batchFile}"

    # Word-split is expected behavior for $_dsconfigOptions. Disable shellcheck.
    # shellcheck disable=SC2086
    eval "dsconfig ${_dsconfigOptions} --batch-file \"${_batchFile}\""
    rm "${_batchFile}"
}

# Save the current java version and jvm options to files in the state directory,
# to be compared next time this container starts up. If either changes, then a new
# java.properties file should be generated with dsjavaproperties --initialize.
#
# @param ${1} The JVM options that will be added to setup-arguments.txt and passed
#             to dsjavaproperties if necessary.
#
# Usage example: save_jvm_settings "--jvmTuningParameter AGGRESSIVE --maxHeapSize 800m"
#
save_jvm_settings() {
    mkdir -p "${JVM_STATE_DIR}"

    # Write passed JVM options for dsjavaproperties
    echo "${1}" > "${JVM_STATE_DIR}/jvmOptions"

    # Write java version info
    # For some reason "java -version" writes its output to stderr instead of stdout
    java -version 2> "${JVM_STATE_DIR}/jvmVersion"
}

# Compare current JVM options and version to previous saved values. If previous
# values are present and match the current, this method will return 0. Otherwise,
# it will return 1.
#
# @param ${1} The JVM options that will be added to setup-arguments.txt and passed
#             to dsjavaproperties if necessary.
#
# Usage example: compare_and_save_jvm_settings "--jvmTuningParameter AGGRESSIVE --maxHeapSize 800m"
#
compare_and_save_jvm_settings() {
    if test -f "${JVM_STATE_DIR}/jvmOptions" && test -f "${JVM_STATE_DIR}/jvmVersion"; then
        mv "${JVM_STATE_DIR}/jvmOptions" "${JVM_STATE_DIR}/jvmOptions.prev"
        mv "${JVM_STATE_DIR}/jvmVersion" "${JVM_STATE_DIR}/jvmVersion.prev"
    fi

    # Write new settings for future restarts
    save_jvm_settings "${1}"

    # Determine if there are any changes
    _diffRC=1
    if test -f "${JVM_STATE_DIR}/jvmOptions.prev" && test -f "${JVM_STATE_DIR}/jvmVersion.prev"; then
        diff "${JVM_STATE_DIR}/jvmOptions.prev" "${JVM_STATE_DIR}/jvmOptions" > /dev/null &&
            diff "${JVM_STATE_DIR}/jvmVersion.prev" "${JVM_STATE_DIR}/jvmVersion" > /dev/null &&
            _diffRC=0
    fi

    return ${_diffRC}
}
