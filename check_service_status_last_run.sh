#!/usr/bin/env bash

# Icinga2 exit codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Get exit code of the service
SERVICE_EXIT_CODE=$(systemctl show -p ExecMainStatus --value ${SERVICE})

# Get the last start time of the service
LAST_START=$(systemctl show -p ActiveEnterTimestamp --value ${SERVICE})

# Get the current time and the time 24 hours ago
CURRENT_TIME=$(date +%s)
TIME_24_HOURS_AGO=$(date -d '24 hours ago' +%s)

# Convert the last start time to a timestamp
LAST_START_TIMESTAMP=$(date -d "$LAST_START" +%s)

# Check if the service has run in the last 24 hours
if [ "$LAST_START_TIMESTAMP" -lt "$TIME_24_HOURS_AGO" ]; then
    SERVICE_EXIT_CODE=1
fi

case "$SERVICE_EXIT_CODE" in
    0)
        echo "OK - Backup completed"
        exit "${OK}"
        ;;
    1)
        echo "CRITICAL - Backup failed"
        exit "${CRITICAL}"
        ;;
    2)
        echo "WARNING - "
        exit "${WARNING}"
        ;;
    *)
        echo "UNKNOWN - No registered exit code"
        exit "${UNKNOWN}"
        ;;
esac
