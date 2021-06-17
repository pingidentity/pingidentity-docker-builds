#!/usr/bin/env sh

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# warn about any UNSAFE_ variables
print_variable_warnings

exit 0
