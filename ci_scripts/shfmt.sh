#!/usr/bin/env sh
#
# Ping Identity DevOps - CI scripts
#
# This script finds all shell files in the current working directory (recursive)
# which contain formatting that differs from shfmt's configuration.
# In --diff mode, diffs of these occurrences are printed
# In --write mode, files are updated to use the configured format for the project.
#
test "${VERBOSE}" = "true" && set -x

# Usage printing function
usage() {
    test -n "${*}" && echo "${*}"
    cat << END_USAGE
Usage: ${0} {options}
    where {options} include:
    -d, --diff
        Finds all shell files in the current working directory (recursive)
        which contain formatting that differs from shfmt's configuration.
        If found, diffs of these occurrences are printed. This is the default.
    -w, --write
        Overwrites all shell files in the current working directory (recursive)
        which contain formatting that differs from shfmt's configuration.
        If found, files are updated to use the configured format for the project.
    -f, --file
        target a specific file rather than the default behavior of analyzing
        all the eligible files in the project
    --help
        Display general usage information
END_USAGE
    exit 99
}

format_file() {
    #Checks for space indents of size 4
    #Checks for spaces following redirects
    #Checks for indented switch case statements
    #Prints diff of actual file vs shfmt format
    "${command_prefix}shfmt" -i 4 -sr -ci "${mode}" "${1}"
    return ${?}
}

while ! test -z "${1}"; do
    case "${1}" in
        -d | --diff)
            mode="-d"
            ;;
        -w | --write)
            mode="-w"
            ;;
        -f | --file)
            shift
            file="${1}"
            ;;
        --help)
            usage
            ;;
        *)
            usage "Unrecognized option"
            ;;
    esac
    shift
done

#Default mode to --diff
if test -z "${mode}"; then
    mode="-d"
fi

command_prefix=""
if ! type shfmt; then
    if test "$(uname -m)" = "x86_64" && test "$(uname -s)" = "Linux"; then
        echo "INFO: Downloading latest shfmt version for Linux"

        # Install shfmt
        shfmt_filename="shfmt"

        # Download the latest version of shfmt for linux x86_64 from GitHub.
        shfmt_download_url=$(curl --silent https://api.github.com/repos/mvdan/sh/releases/latest | jq -r '.assets[] | select(.name|test("linux_amd64")) | .browser_download_url')
        test -z "${shfmt_download_url}" && echo "Error: Failed to retrieve shfmt download URL" && exit 1
        curl --location --silent --output "${shfmt_filename}" "${shfmt_download_url}"
        test $? -ne 0 && echo "Error: Failed to retrieve shfmt binary from GitHub" && exit 1

        # Give execute permissions to shfmt
        chmod +x shfmt
        test $? -ne 0 && echo "Error: Failed to exit execute permissions on shfmt binary" && exit 1

        command_prefix="./"
    else
        echo "Missing shfmt"
        exit 99
    fi
fi

num_files_fail_shfmt=0
if test -n "${file}"; then
    echo "Checking format of ${file}"
    format_file "${file}"
    test $? -ne 0 && num_files_fail_shfmt=$((num_files_fail_shfmt + 1))
else
    # For each file in the project, if it starts with a shebang, add it to a list in tmp.
    # This is used in favor of "shfmt -f ." as shfmt does not consider files with extension
    # .pre, .post, etc. as shell.
    find "$(pwd)" -type f -not -path '*/\.*' -exec awk 'FNR==1 {if ($0~/^#!/){print FILENAME}}' {} + > tmp

    test "${VERBOSE}" = "true" && echo "Files in use:" && cat tmp

    # Scan each file in tmp with shfmt
    while IFS= read -r shell_file; do
        format_file "${shell_file}"
        test $? -ne 0 && num_files_fail_shfmt=$((num_files_fail_shfmt + 1))
    done < tmp
    rm tmp
fi
test -n "${command_prefix}" && rm shfmt

test "${mode}" = "-d" && echo "Number of Files that do not match shfmt format: ${num_files_fail_shfmt}"
if test ${num_files_fail_shfmt} -ne 0; then
    exit 1
fi
exit 0
