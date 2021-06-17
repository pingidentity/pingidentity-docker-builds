#!/usr/bin/env sh

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# Append ldif template files in the pd.profile to the variables-ignore.txt file
appendTemplatesToVariablesIgnore() {
    find "${PD_PROFILE}/ldif" -maxdepth 1 -mindepth 1 -type d 2> /dev/null | while read -r _ldifDir; do
        find "${_ldifDir}" -type f -iname \*.template 2> /dev/null | while read -r _template; do
            # Add the generated ldif file to the profile's variables-ignore.txt file, to avoid
            # the potential memory overhead of variable substitution on a large file.
            _generatedLdifFilename="${_template%.*}.ldif"
            _generatedLdifBasename=$(basename "${_generatedLdifFilename}")
            _backendID=$(basename "${_ldifDir}")
            echo "ldif/${_backendID}/${_generatedLdifBasename}" >> "${PD_PROFILE}/variables-ignore.txt"
        done
    done
}
