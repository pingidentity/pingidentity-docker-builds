#!/usr/bin/env sh
curl -ssk -o /dev/null http://localhost:${HTTPS_PORT}/ || exit 1
exit 0