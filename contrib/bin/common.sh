#!/bin/sh

DOCKER_TAG_BASE="nearaurora"
DOCKER_TAG_PREFIX="srpc2-"
DOCKER_TAG_RELAYER="${DOCKER_TAG_BASE}/${DOCKER_TAG_PREFIX}relayer"
DOCKER_TAG_REFINER="${DOCKER_TAG_BASE}/${DOCKER_TAG_PREFIX}refiner"

INSTALL_DIR="srpc2"

confirmed() {
    local OPTIND
    local OPTARG
    prompt="$1"
    shift
    while getopts ":q" opt; do
        if [ "$opt" = "q" ]; then
            return 0
        fi
    done

    read -p "$prompt [y/N]: " opt
    case "$opt" in
        y|Y)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}