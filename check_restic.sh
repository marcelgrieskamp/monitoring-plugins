#!/usr/bin/env bash

# Source: We used artificial intelligence (ChatGPT).

# Function to display usage information
usage() {
	echo "Usage: ${0} -w <warning_hours> -c <critical_hours>"
	exit 3 # Exit with UNKNOWN status
}

# Parse command line options
while getopts ":w:c:" opt; do
	case ${opt} in
	w)
		warning_hours="${OPTARG}"
		;;
	c)
		critical_hours="${OPTARG}"
		;;
	\?)
		echo "Invalid option: -${OPTARG}"
		usage
		;;
	:)
		echo "Option -${OPTARG} requires an argument."
		usage
		;;
	esac
done

# Check if warning and critical options are provided
if [[ -z ${warning_hours} ]] || [[ -z ${critical_hours} ]]; then
	echo "Warning and critical options are required."
	usage
fi

# Source environment variables from the configuration file
config_file="/etc/backup/.restic.env"
if [[ -f ${config_file} ]]; then
	source "${config_file}"
else
	echo "CRITICAL: Configuration file not found: ${config_file}"
	exit 2 # Exit with CRITICAL status
fi

# Icinga2 exit codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Get the latest snapshot timestamp
latest_snapshot=$(restic -r "${RESTIC_REPOSITORY}" snapshots --json | jq -r '.[-1].time')

# Check if the latest snapshot is a valid timestamp
if ! date -d "${latest_snapshot}" >/dev/null 2>&1; then
	echo "UNKNOWN: Invalid timestamp format for the latest Restic snapshot"
	exit "${UNKNOWN}"
fi

# Calculate the threshold timestamps
warning_threshold=$(date -d "${latest_snapshot} + ${warning_hours} hours" +%s)
critical_threshold=$(date -d "${latest_snapshot} + ${critical_hours} hours" +%s)

# Check if the latest snapshot is within the warning threshold
if [[ "$(date -d "${latest_snapshot}" +%s)" -ge ${warning_threshold} ]]; then
	# Check if the latest snapshot is within the critical threshold
	if [[ "$(date -d "${latest_snapshot}" +%s)" -ge ${critical_threshold} ]]; then
		echo "CRITICAL: Latest Restic backup is older than ${critical_hours} hours"
		exit "${CRITICAL}"
	else
		echo "WARNING: Latest Restic backup is older than ${warning_hours} hours but within ${critical_hours} hours"
		exit "${WARNING}"
	fi
else
	echo "OK: Latest Restic backup within the last ${warning_hours} hours and successful"
	exit "${OK}"
fi
