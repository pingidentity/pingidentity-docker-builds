#!/usr/bin/env sh

echo "####################################################################################"
echo "#  Starting Helm Test"
echo "#"
echo "#    $(date)"
echo "####################################################################################"

echo "Args: $*"

date > /var/run/shared/test.date

exit 0
