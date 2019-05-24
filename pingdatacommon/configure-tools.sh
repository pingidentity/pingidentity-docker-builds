#!/bin/sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# ARG1 => port; ARG2 => bindDN; ARG3 => bindPasswordFile
# ARG4 => adminUID; ARG5 => adminPassword

echo "Configuring tools.properties"
TOOLS_PROPERTIES_FILE="${SERVER_ROOT_DIR}"/config/tools.properties

sed -i.bak 's/^#\s*\(.*=.*\)$/\1/' "${TOOLS_PROPERTIES_FILE}"
sed -i.bak "s/^\(.*\)\(port\)=.*$/\1\2=$1/" "${TOOLS_PROPERTIES_FILE}"

if grep "bindDN=" "${TOOLS_PROPERTIES_FILE}" >/dev/null; then
  sed -i.bak "s/^\(bindDN\)=.*$/\1=$2/" "${TOOLS_PROPERTIES_FILE}"
else
  echo "bindDN=$2" >> "${TOOLS_PROPERTIES_FILE}"
fi

if grep "bindPassword=" "${TOOLS_PROPERTIES_FILE}" >/dev/null; then
  sed -i.bak "s/^\(bindPassword=.*\)$/#\1/" "${TOOLS_PROPERTIES_FILE}"
fi

# shellcheck disable=2129
echo "bindPasswordFile=$3" >> "$TOOLS_PROPERTIES_FILE"

echo "adminUID=$4" >> "$TOOLS_PROPERTIES_FILE"
echo "adminPasswordFile=$5" >> "$TOOLS_PROPERTIES_FILE"

echo "suppressPropertiesFileComment=true" >> "${TOOLS_PROPERTIES_FILE}"

sed -i.bak "s/^[ 	]*//" "${TOOLS_PROPERTIES_FILE}"
