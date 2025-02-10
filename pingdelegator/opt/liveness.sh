#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

curl -sSk -o /dev/null "https://127.0.0.1:${PD_DELEGATOR_HTTPS_PORT}/" || exit 1
exit 0
