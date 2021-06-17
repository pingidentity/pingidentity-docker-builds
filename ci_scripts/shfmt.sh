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
    --help
        Display general usage information
END_USAGE
    exit 99
}

while ! test -z "${1}"; do
    case "${1}" in
        -d | --diff)
            mode="-d"
            ;;
        -w | --write)
            mode="-w"
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

if test -n "${CI_COMMIT_REF_NAME}"; then
    #We are in the pipeline
    # Install shfmt
    curl -O https://gte-bits-repo.s3.amazonaws.com/shfmt
    chmod +x shfmt
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

num_files_fail_shfmt=0
# Scan each file in tmp with shfmt
while IFS= read -r shell_file; do
    #Checks for space indents of size 4
    #Checks for spaces following redirects
    #Checks for indented switch case statements
    #Prints diff of actual file vs shfmt format
    "${command_prefix}shfmt" -i 4 -sr -ci "${mode}" "${shell_file}"
    test $? -ne 0 && num_files_fail_shfmt=$((num_files_fail_shfmt + 1))
done < tmp
rm tmp

test -n "${command_prefix}" && rm shfmt

test "${mode}" = "-d" && echo "Number of Files that do not match shfmt format: ${num_files_fail_shfmt}"

if test ${num_files_fail_shfmt} -ne 0; then
    exit 1
fi
exit 0
