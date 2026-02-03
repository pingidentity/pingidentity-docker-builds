#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

echo "####################################################################################"
echo "#  Starting Helm Test"
echo "#"
echo "#    $(date)"
echo "####################################################################################"

echo "Args: $*"

date > /var/run/shared/test.date

exit 0
