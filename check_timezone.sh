#!/usr/bin/env bash

# Icinga2 exit codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Function to display usage information
usage() {
    echo "Usage: ${0} -t <timezone>" >&2
    exit "${UNKNOWN}" # Exit with UNKNOWN status
}

# Parse command line options
while getopts ":t:" opt; do
    case ${opt} in
    t)
        TIMEZONE="${OPTARG}"
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

if [[ -z ${TIMEZONE} ]]; then
    echo "Timezone argument is required"
    usage
    exit "${CRITICAL}"
fi


SET_TIMEZONE=$(timedatectl show -p "Timezone" --value)

if [ "$SET_TIMEZONE" = "$TIMEZONE" ]; then
    echo "OK - Timezone matches $TIMEZONE"
    exit "${OK}"
else
    echo "CRITICAL - Timezone $SET_TIMEZONE not matches $TIMEZONE"
    exit "${CRITICAL}"
fi

echo "UNKNOWN - Couldn't check timezone"
exit "${UNKNOWN}"
