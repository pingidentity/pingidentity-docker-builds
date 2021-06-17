#!/usr/bin/env sh
if test "$(id -u)" -ne 0; then
    echo This tool must be run as root
    exit 1
fi
cat << END_DISCLAIMER
################################################################################
#                                  NOTICE                                      #
################################################################################
Ping Identity uninstalls the package manager to reduce the attack surface in 
its docker images.
Reinstalling the package manager is a distinctly bad practice and invites
potential abuse from malicious actors.
We realize that in certain circumstances, this can mean the difference between
being blocked and getting to the root cause of an issue so that is why we
provide it here and it should be used with parsimony and only in circumstances
where you need to install debug tools from the package repository.

Please confirm you understand and want to proceed?
type y to proceed, anything else to bail
END_DISCLAIMER
read -r userResponse
test "${userResponse}" = "y" || exit 2

cd / || exit 3
_ver=$(awk -F= '$1~/VERSION_ID/{gsub(/"/,"",$2);gsub(/\.[0-9]+$/,"",$2);print $2;}' /etc/os-release)
_arch=$(uname -m)
_url="http://dl-cdn.alpinelinux.org/alpine/v${_ver}/main/${_arch}/"
_apk=$(curl -s "${_url}" | awk '$0~/apk-tools-static/ {sub(/.*href="/,"",$2);sub(/".*$/,"",$2);print $2}')
curl -s "${_url}/${_apk}" | tar xvzf -
ln -s /sbin/apk.static /sbin/apk
apk -X http://dl-cdn.alpinelinux.org/alpine/latest-stable/main -U --allow-untrusted --initdb add apk-tools-static
apk update
# /sbin/apk.static -X http://dl-cdn.alpinelinux.org/alpine/latest-stable/main -U --allow-untrusted add apk-tools
# apk update
