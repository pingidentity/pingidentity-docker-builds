#!/usr/bin/env sh
curl -ssk -o /dev/null https://localhost:${PD_DELEGATOR_HTTPS_PORT}/ || exit 1
exit 0