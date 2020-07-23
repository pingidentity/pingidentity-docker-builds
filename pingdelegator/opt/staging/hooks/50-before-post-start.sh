#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This is called after the start or restart sequence has finished and before
#- the server within the container starts
#

echo ""
echo "You may see an alert when nginx starts due to the order of how the error_log gets opened when nginx starts.  This alert can be ignored."
echo ""
echo "The alert will look like: nginx: [alert] could not open error log file: open() \"/var/lib/nginx/logs/error.log\" failed (13: Permission denied)"
echo ""