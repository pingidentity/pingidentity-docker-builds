#!/usr/bin/env sh
#
# Ping Identity DevOps - CI scripts
#
# This script finds all shell files in the current working directory (recursive)
# and runs shellcheck on them. Shellcheck warnings and number of files with warnings are printed.
#
test "${VERBOSE}" = "true" && set -x

if test -n "${CI_COMMIT_REF_NAME}"; then
    #We are in the pipeline
    # Install shellcheck
    curl -O https://gte-bits-repo.s3.amazonaws.com/shellcheck
    chmod +x shellcheck
    command_prefix="./"
else
    #We are on local
    command_prefix=""
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
