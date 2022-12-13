#!/usr/bin/env sh
#
# Ping Identity DevOps - CI scripts
#
# This script finds all shell files in the current working directory (recursive)
# and runs shellcheck on them. Shellcheck warnings and number of files with warnings are printed.
#
test "${VERBOSE}" = "true" && set -x

command_prefix=""
if ! type shellcheck; then
    if test "$(uname -m)" = "x86_64" && test "$(uname -s)" = "Linux"; then
        echo "INFO: Downloading latest shellcheck version for Linux"

        # Install shellcheck
        shellcheck_filename="shellcheck.tar.xz"

        # Download the latest version of shellcheck for linux x86_64 from GitHub.
        shellcheck_download_url=$(curl --silent https://api.github.com/repos/koalaman/shellcheck/releases/latest | jq -r '.assets[] | select(.name|test("linux.x86_64")) | .browser_download_url')
        test -z "${shellcheck_download_url}" && echo "Error: Failed to retrieve shellcheck download URL" && exit 1
        curl --location --silent --output "${shellcheck_filename}" "${shellcheck_download_url}"
        test $? -ne 0 && echo "Error: Failed to retrieve shellcheck tar file from GitHub" && exit 1

        # Extract the binary
        tar -xf "${shellcheck_filename}" --exclude 'README.txt' --exclude 'LICENSE.txt' --strip-components=1
        test $? -ne 0 && echo "Error: Failed to extract shellcheck binary" && exit 1

        # Give execute permissions to shellcheck
        chmod +x shellcheck
        test $? -ne 0 && echo "Error: Failed to exit execute permissions on shellcheck binary" && exit 1

        command_prefix="./"
    else
        echo "Missing shellcheck"
        exit 99
    fi
fi

# For each file in the project, if it starts with a shebang, add it to a list in tmp.
# This is used in favor of "shfmt -f ." as shfmt does not consider files with extension
# .pre, .post, etc. as shell.
find "$(pwd)" -type f -not -path '*/\.*' -exec awk 'FNR==1 {if ($0~/^#!/){print FILENAME}}' {} + > tmp

test "${VERBOSE}" = "true" && echo "Files in use:" && cat tmp

num_files_fail_shellcheck=0
# Scan each file in tmp with shellcheck
while IFS= read -r shell_file; do
    #Exclude SC1090 and SC1091 as files are not being found, despite shellcheck source definitions.
    "${command_prefix}shellcheck" --exclude=SC1090,SC1091 "${shell_file}"
    test $? -ne 0 && num_files_fail_shellcheck=$((num_files_fail_shellcheck + 1))
done < tmp
rm tmp

test -n "${command_prefix}" && rm shellcheck

echo "Number of Files with Shellcheck Warnings: ${num_files_fail_shellcheck}"

if test ${num_files_fail_shellcheck} -ne 0; then
    exit 1
fi
exit 0
