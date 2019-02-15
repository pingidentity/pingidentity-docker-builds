#!/bin/sh
set -x

LOG_FILE="${SERVER_ROOT_DIR}/logs/preStop.log"
TOP_FILE="${IN_DIR}/topology.json"

if [[ ! -f "${TOP_FILE}" ]]; then
  echo "${TOP_FILE} not found" > $LOG_FILE
  exit 0
fi

echo "Starting preStop script on $HOSTNAME" > $LOG_FILE

