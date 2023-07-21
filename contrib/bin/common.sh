#!/bin/sh

DOCKER_TAG_BASE="nearaurora"
DOCKER_TAG_PREFIX="srpc2-"
DOCKER_TAG_RELAYER="${DOCKER_TAG_BASE}/${DOCKER_TAG_PREFIX}relayer"
DOCKER_TAG_REFINER="${DOCKER_TAG_BASE}/${DOCKER_TAG_PREFIX}refiner"

INSTALL_DIR="srpc2"
VERSION_FILE="${INSTALL_DIR}/.version"

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

beginswith() { case "$2" in "$1"*) true;; *) false;; esac; }

to_upper_first() {
  upper_first=$(echo "$1" | cut -c1 | tr [a-z] [A-Z])
  rest=$(echo "$1" | cut -c2-)
  echo "$upper_first$rest"
}