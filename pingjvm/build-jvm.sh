#!/usr/bin/env sh
test "${VERBOSE}" = "true" && set -x

_osID=$(awk '$0~/^ID=/ {split($1,id,"="); gsub(/"/,"",id[2]); print id[2];}' < /etc/os-release 2> /dev/null)
_osArch=$(uname -m)

# If there is no Java, we'll pull down Liberica Standard JDK
if ! type java > /dev/null 2> /dev/null; then
    #Modify the following variables to update Alpine and RHEL image's JDK.
    case "${JVM_ID}" in
        al11 | rl11)
            JDK_VERSION="11.0.19+7"
            alpine_x86_64_checksum="740971cb639d30266485187fe842927558cd7acf"
            alpine_aarch64_checksum="36f80b6bc0d66c0cfb0c3a9ca81bd148f1124d77"
            redhat_x86_64_checksum="40d35ac207e65431e5a3d688855ab0f4d80d0340"
            ;;
        al17)
            JDK_VERSION="17.0.7+7"
            alpine_x86_64_checksum="bd7b1dc9d89966872337481959202397540d49e2"
            alpine_aarch64_checksum="f2d590b04e022d188a5545de7337ea9285e70c07"
            redhat_x86_64_checksum="9696fb0d696b0d52a0d3f0233a538396b62a93a5"
            ;;
        *)
            echo "ERROR: Unrecognized JVM_ID: ${JVM_ID}" && exit 1
            ;;
    esac

    case "${_osID}" in
        alpine)
            case "${_osArch}" in
                x86_64)
                    download_arch="x64"
                    jdk_sha_checksum="${alpine_x86_64_checksum}"
                    echo "No java found. Pulling down Liberica Standard JDK for Alpine Linux x86_64..."
                    ;;
                aarch64)
                    download_arch="${_osArch}"
                    jdk_sha_checksum="${alpine_aarch64_checksum}"
                    echo "No java found. Pulling down Liberica Standard JDK for Alpine Linux aarch64..."
                    ;;
                *)
                    echo "ERROR: Unsupported architecture ${_osArch} for OS ${_osID}" && exit 90
                    ;;
            esac
            download_libc="-musl"
            download_cmd="wget -O"

            # Get binutils for jlinking with Liberica JDK 17 on alpine
            apk --no-cache --update add binutils
            ;;
        rhel)
            case "${_osArch}" in
                x86_64)
                    download_arch="amd64"
                    jdk_sha_checksum="${redhat_x86_64_checksum}"
                    echo "No java found. Pulling down Liberica Standard JDK for Redhat UBI x86_64..."
                    ;;
                *)
                    echo "ERROR: Unsupported architecture ${_osArch} for OS ${_osID}" && exit 91
                    ;;
            esac
            # Word-splitting expected in listing microdnf packages to install
            # shellcheck disable=SC2086
            microdnf -y install tar gzip findutils wget
            download_cmd="curl -o"
            download_libc=""
            ;;
        *)
            echo "ERROR: Unsupported OS ${_osID} for building pingjvm with Liberica Standard JDK" && exit 92
            ;;
    esac

    temp_jdk_dir="$(mktemp -d)"
    jdk_tar_file="${temp_jdk_dir}/jdk.tgz"
    jdk_download_url="https://download.bell-sw.com/java/${JDK_VERSION}/bellsoft-jdk${JDK_VERSION}-linux-${download_arch}${download_libc}.tar.gz"

    #Download the jdk tar file
    eval "${download_cmd}" "${jdk_tar_file}" "${jdk_download_url}"
    jdk_file_sha_checksum="$(sha1sum "${jdk_tar_file}" | awk '{print $1}')"
    test "${jdk_sha_checksum}" != "${jdk_file_sha_checksum}" &&
        echo "ERROR: JDK tar file checksum does not match. Expected: ${jdk_sha_checksum} Actual: ${jdk_file_sha_checksum}" &&
        exit 93

    #Extract the jdk
    ! type tar > /dev/null 2>&1 && _prefix="./busybox"
    ${_prefix} tar -C "${temp_jdk_dir}" -xzf "${jdk_tar_file}"
    rm "${jdk_tar_file}"

    #Set JAVA_HOME and update PATH
    JAVA_HOME="$(find "${temp_jdk_dir}" -type d -name jdk-\*)"
    export JAVA_HOME
    export PATH="${JAVA_HOME}/bin:${PATH}"
fi

# Location to move java to inside pingjvm image
JAVA_BUILD_DIR="/opt/java"

# If jlink is present, then we assume to be interacting with a JDK
if type "${JAVA_HOME}/bin/jlink" > /dev/null 2> /dev/null; then
    MODULES_PATH="${JAVA_HOME}/jmods"
    # If jmods directory is present, we can jlink the jdk
    if test -d "${MODULES_PATH}"; then
        # build the list of all modules if not provided.
        # worst case scenario, when moving to a new JDK with different modules we haven't had time to prune
        if test -z "${modules_list}"; then
            for i in "${JAVA_HOME}/jmods"/*.jmod; do
                modules_list="${modules_list:+${modules_list},}$(basename "${i%.jmod}")"
            done
        fi

        #Expect modules_list to be non-empty otherwise jlink command may break
        test -z "${modules_list}" && echo "ERROR: No modules list provided or found. Unable to jlink." && exit 94

        # Verify we have a viable jvm before jlink
        "${JAVA_HOME}/bin/java" -version
        test ${?} -ne 0 && echo "ERROR: No viable JVM found before jlink." && exit 95

        # Word-split is expected behavior for $_modules. Disable shellcheck.
        # shellcheck disable=SC2086
        "${JAVA_HOME}/bin/jlink" \
            --compress=2 \
            --no-header-files \
            --no-man-pages \
            --verbose \
            --strip-debug \
            --module-path "${MODULES_PATH}" \
            --add-modules ${modules_list} \
            --output "${JAVA_BUILD_DIR}"
        test ${?} -ne 0 && echo "ERROR: Unsuccessful jlink." && exit 96

        # verify JAVA_BUILD_DIR was created/exists
        ! test -d "${JAVA_BUILD_DIR}" && echo "ERROR: ${JAVA_BUILD_DIR} does not exist after jlink" && exit 97
    else
        # We have a jlink'd jdk, simply move it to JAVA_BUILD_DIR
        cp -rf "${JAVA_HOME}" "${JAVA_BUILD_DIR}"
    fi
else
    # No jlink present, assume to be interacting with a JRE
    # This seemingly slightly over-complicated strategy to move the JRE to /opt/java
    # is necessary because some distros (namely adopt hotspot) have the JRE under /opt/java/<something>
    mkdir -p /opt 2> /dev/null
    _java_actual=$(readlink -f "${JAVA_HOME}/bin/java")
    _java_home_actual=$(dirname "$(dirname "${_java_actual}")")
    mv "${_java_home_actual}" /tmp/java
    rm -rf "${JAVA_BUILD_DIR}"
    mv /tmp/java "${JAVA_BUILD_DIR}"
fi

# Remove jdk download directory if present
# It is no longer needed as java should now exist in JAVA_BUILD_DIR
test -n "${temp_jdk_dir}" && test -d "${temp_jdk_dir}" && rm -rf "${temp_jdk_dir}"

# Verify we produced a viable jvm
${JAVA_BUILD_DIR}/bin/java -version
test ${?} -ne 0 && exit 98

# Write java version into a file for later use, preventing inefficient calls to `java -version`
${JAVA_BUILD_DIR}/bin/java -version 2>&1 | tee > /opt/java/_version

# delete self
rm -f "${0}"
exit 0
