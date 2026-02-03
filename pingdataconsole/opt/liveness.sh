#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

curl -sSk -o /dev/null "https://127.0.0.1:${HTTPS_PORT}/" || exit 1
exit 0
