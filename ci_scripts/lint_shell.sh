#!/usr/bin/env sh
#
# Ping Identity DevOps - CI scripts
#
# This script runs shellcheck on every shell script in the docker-builds project.
# The script's exits with exitcode equal to the number of files that have failed shellcheck.
#

test "${VERBOSE}" = "true" && set -x

# Install shellcheck
curl -O https://gte-bits-repo.s3.amazonaws.com/shellcheck
chmod +x shellcheck

# For each file in the project, if it starts with a shebang, add it to a list in tmp.
find "." -type f -exec awk 'FNR==1 {if ($0~/^#!/){print FILENAME}}' {} + > tmp

num_files_fail_shellcheck=0
# Scan each file in tmp with shellcheck
while IFS= read -r shell_file
do
    #Exclude SC1090 and SC1091 as files are not being found, despite shellcheck source definitions.
    ./shellcheck --exclude=SC1090,SC1091 "${shell_file}"
    test $? -ne 0 && num_files_fail_shellcheck=$(( num_files_fail_shellcheck + 1 ))
done < tmp
rm tmp

rm shellcheck

echo "Number of Files with Shellcheck Warnings: ${num_files_fail_shellcheck}"

exit ${num_files_fail_shellcheck}
