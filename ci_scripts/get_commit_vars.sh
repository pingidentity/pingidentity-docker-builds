#!/usr/bin/env sh
message=$(git show -s --format=%B HEAD)
# eval "$1"=true
# echo "$test_only"
contains() {
    string="$message"
    substring="$1"
    if test "${string#*$substring}" != "$string"
    then
        eval "$1"=true
    else
        return 1    # $substring is not in $string
    fi
}
contains $1


# contains "abcd" "e" || echo "abcd does not contain e"
# contains "abcd" "ab" && echo "abcd contains ab"
# contains "abcd" "bc" && echo "abcd contains bc"
# contains "abcd" "cd" && echo "abcd contains cd"
# contains "abcd" "abcd" && echo "abcd contains abcd"
# contains "" "" && echo "empty string contains empty string"
# contains "a" "" && echo "a contains empty string"
# contains "" "a" || echo "empty string does not contain a"
# contains "abcd efgh" "cd ef" && echo "abcd efgh contains cd ef"
# contains "abcd efgh" " " && echo "abcd efgh contains a space"
# echo "$message"