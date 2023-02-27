#!/usr/bin/env sh
curl -ssk -o /dev/null "https://127.0.0.1:${HTTPS_PORT}/" || exit 1
exit 0
