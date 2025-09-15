#!/bin/bash

# Docker Image Monitoring Script
# Checks for unused Docker images and compares against warning/critical thresholds

# Icinga2 Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Parse command line arguments
while getopts "w:c:" opt; do
    case $opt in
        w)
            WARNING_THRESHOLD="$OPTARG"
            ;;
        c)
            CRITICAL_THRESHOLD="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit $UNKNOWN
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit $UNKNOWN
            ;;
    esac
done

# Check if required parameters are provided
if [ -z "$WARNING_THRESHOLD" ] || [ -z "$CRITICAL_THRESHOLD" ]; then
    echo "Error: Both -w and -c parameters are required"
    exit $UNKNOWN
fi

# Validate that thresholds are numeric
if ! [[ "$WARNING_THRESHOLD" =~ ^[0-9]+$ ]] || ! [[ "$CRITICAL_THRESHOLD" =~ ^[0-9]+$ ]]; then
    echo "Error: Warning and critical thresholds must be numeric"
    exit $UNKNOWN
fi

# Validate that critical >= warning
if [ "$CRITICAL_THRESHOLD" -lt "$WARNING_THRESHOLD" ]; then
    echo "Error: Critical threshold must be greater than or equal to warning threshold"
    exit $UNKNOWN
fi

# Get all Docker images (including dangling images)
ALL_IMAGES=$(sudo docker images --format "{{.Repository}}:{{.Tag}}")

# Get images currently in use by containers (running and stopped)
USED_IMAGES=$(sudo docker ps -a --format "{{.Image}}")

# Count total images
TOTAL_IMAGES=$(echo "$ALL_IMAGES" | wc -l)

# Find unused images by comparing image names
UNUSED_IMAGES_LIST=""
UNUSED_COUNT=0

while IFS= read -r image; do
    if [ -n "$image" ]; then
        # Check if this image is NOT used by any container
        IS_USED=false
        while IFS= read -r used_image; do
            if [ -n "$used_image" ]; then
                # Check exact match
                if [ "$image" = "$used_image" ]; then
                    IS_USED=true
                    break
                fi
                # Check if used_image is the base name without tag (e.g., "image" matches "image:latest")
                IMAGE_BASE=$(echo "$image" | cut -d: -f1)
                if [ "$used_image" = "$IMAGE_BASE" ]; then
                    IS_USED=true
                    break
                fi
                # Check if image is the base name of used_image (e.g., "image:latest" matches "image")
                USED_IMAGE_BASE=$(echo "$used_image" | cut -d: -f1)
                if [ "$image" = "$USED_IMAGE_BASE" ]; then
                    IS_USED=true
                    break
                fi
            fi
        done <<< "$USED_IMAGES"
        
        if [ "$IS_USED" = false ]; then
            # Remove any colon at the end
            CLEAN_IMAGE=$(echo "$image" | sed 's/:$//' | sed 's/[: ]*$//')
            if [ -z "$UNUSED_IMAGES_LIST" ]; then
                UNUSED_IMAGES_LIST="$CLEAN_IMAGE"
            else
                UNUSED_IMAGES_LIST="$UNUSED_IMAGES_LIST"$'\n'"$CLEAN_IMAGE"
            fi
            ((UNUSED_COUNT++))
        fi
    fi
done <<< "$ALL_IMAGES"

UNUSED_IMAGES=$UNUSED_COUNT

# Determine status and exit
if [ "$UNUSED_IMAGES" -ge "$CRITICAL_THRESHOLD" ]; then
    echo "CRITICAL - Unused images: $UNUSED_IMAGES | unused_images=$UNUSED_IMAGES;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;0;$TOTAL_IMAGES"
    
    if [ "$UNUSED_IMAGES" -gt 0 ]; then
        echo "$UNUSED_IMAGES_LIST"
    fi
    
    exit $CRITICAL
elif [ "$UNUSED_IMAGES" -ge "$WARNING_THRESHOLD" ]; then
    echo "WARNING - Unused images: $UNUSED_IMAGES | unused_images=$UNUSED_IMAGES;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;0;$TOTAL_IMAGES"
    
    if [ "$UNUSED_IMAGES" -gt 0 ]; then
        echo "$UNUSED_IMAGES_LIST"
    fi
    
    exit $WARNING
else
    echo "OK - Unused images: $UNUSED_IMAGES | unused_images=$UNUSED_IMAGES;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;0;$TOTAL_IMAGES"
    exit $OK
fi
