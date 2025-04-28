#!/usr/bin/env bash

# Icinga2 exit codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Function to display usage information
usage() {
    echo "Usage: ${0} -s <service>" >&2
    exit "${UNKNOWN}" # Exit with UNKNOWN status
}

# Check if systemctl is available
if ! command -v systemctl >/dev/null 2>&1; then
    echo "UNKNOWN - 'systemctl' command not found. Ensure you are running this script on a system with systemd." >&2
    exit "${UNKNOWN}"
fi

# Parse command line options
while getopts ":s:" opt; do
    case ${opt} in
    s)
        SERVICE="${OPTARG}"
        ;;
    \?)
        echo "Invalid option: -${OPTARG}" >&2
        usage
        ;;
    :)
        echo "Option -${OPTARG} requires an argument." >&2
        usage
        ;;
    esac
done

# Validate that SERVICE is provided
if [ -z "${SERVICE}" ]; then
    echo "UNKNOWN - No service specified. Use the -s option to specify a service." >&2
    usage
fi

# Check that the service exists
if systemctl list-unit-files --type=service --all | grep -q "^${SERVICE}"; then
    # Get exit code of the service
    SERVICE_EXIT_CODE=$(systemctl show -p ExecMainStatus --value "${SERVICE}")

    # Get the last start time of the service
    LAST_START=$(systemctl show -p ActiveEnterTimestamp --value "${SERVICE}")

    # Validate LAST_START
    if [ -z "${LAST_START}" ]; then
        echo "UNKNOWN - Unable to retrieve the last start time for service '${SERVICE}'." >&2
        exit "${UNKNOWN}"
    fi

    # Get the current time and the time 24 hours ago
    CURRENT_TIME=$(date +%s)
    TIME_24_HOURS_AGO=$(date -d '24 hours ago' +%s)

    # Convert the last start time to a timestamp
    LAST_START_TIMESTAMP=$(date -d "$LAST_START" +%s 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "UNKNOWN - Failed to parse the last start time ('${LAST_START}') for service '${SERVICE}'." >&2
        exit "${UNKNOWN}"
    fi

    # Check if the service has run in the last 24 hours
    if [ "$LAST_START_TIMESTAMP" -lt "$TIME_24_HOURS_AGO" ]; then
        SERVICE_EXIT_CODE=1
    fi
else
    echo "UNKNOWN - Service '${SERVICE}' does not exist." >&2
    exit "${UNKNOWN}"
fi

# Handle the service status
case "$SERVICE_EXIT_CODE" in
    0)
        echo "OK - Service '${SERVICE}' completed successfully."
        exit "${OK}"
        ;;
    1)
        echo "CRITICAL - Service '${SERVICE}' failed or has not run in the last 24 hours."
        exit "${CRITICAL}"
        ;;
    2)
        echo "WARNING - Service '${SERVICE}' is in a warning state."
        exit "${WARNING}"
        ;;
    *)
        echo "UNKNOWN - Unable to determine the status of service '${SERVICE}'."
        exit "${UNKNOWN}"
        ;;
esac
