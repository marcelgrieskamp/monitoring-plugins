#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Script for getting an overview about not up-to-date docker containers
# Set variable "TRACE" to "1" for debugging.

# sudo permissions for the user (nagios)
# nagios ALL=NOPASSWD: /usr/bin/docker pull *
# nagios ALL=NOPASSWD: /usr/bin/docker ps -qa
# nagios ALL=NOPASSWD: /usr/bin/docker images -q
# nagios ALL=NOPASSWD: /usr/bin/docker inspect --format *
# nagios ALL=NOPASSWD: /usr/bin/docker images -aq --no-trunc *


remove_prefix_if_domain_exists() {
    url="$1"
    # Check for pattern *.* before the first /
    if [[ $url =~ ^[^/]*\.[a-zA-Z]{2,} ]]; then
        parts=(${url//\// })
        if [ ${#parts[@]} -gt 1 ]; then
            echo "${url#*/}"
        else
            echo ""
        fi
    else
        echo "$url"
    fi
}

main() {
    trap "echo 'ERROR - An error has occurred.'; exit 2" ERR

    # check for sudo:
    sudo /usr/bin/docker images -aq --no-trunc '*' >> /dev/null

    # Update Images
    for IMAGE in $(sudo docker images -q || exit 3); do
        REPO=$(sudo docker inspect --format "{{.RepoTags}}" $IMAGE | sed "s/\[//g" | sed "s/\]//g")

        if [ -z "$REPO" ]; then
            echo "ERROR - Repository name not found for image $IMAGE. Exiting..."
            exit 2
        fi

        REPO_NAME=$(echo $REPO | cut -d':' -f1)
        REPO_TAG=$(echo $REPO | cut -d':' -f2)

        if [ -z "$REPO_TAG" ]; then
            echo "ERROR - Repository tag not found for image $IMAGE. Exiting..."
            exit 2
        fi

        # Pull the updated image
        sudo docker pull $REPO_NAME:$REPO_TAG > /dev/null 2>&1
    done

    # Wait until all subprocesses finish:
    while [ $(pgrep -c -P$$) -gt 0 ]; do
        sleep 1
    done

    UPD=""
    for CONTAINER in $(sudo docker ps -qa); do
        NAME=$(sudo docker inspect --format '{{.Name}}' $CONTAINER | sed "s/\///g")
        REPO=$(sudo docker inspect --format '{{.Config.Image}}' $CONTAINER)

        # Remove the domain part if it exists.
        REPO=$(remove_prefix_if_domain_exists "$REPO")

        IMG_RUNNING=$(sudo docker inspect --format '{{.Image}}' $CONTAINER)
        IMG_LATEST=$(sudo docker images -aq --no-trunc $REPO)

        if [ "$IMG_RUNNING" != "$IMG_LATEST" ]; then
            if [ -n "$UPD" ]; then
                UPD="${UPD}, ${NAME}"
            else
                UPD="${NAME}"
            fi
        fi
    done

    if [ -n "$UPD" ]; then
        echo "WARNING - Update available for these containers:"
        echo "${UPD}"
        exit 1
    else
        echo "OK - no updates needed"
        exit 0
    fi
}

#### ARGUMENTS ####

if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

## MAIN ###
cd "$(dirname "$0")"

main "$@"
