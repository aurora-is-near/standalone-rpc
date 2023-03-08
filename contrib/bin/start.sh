#!/bin/sh

script_home=$(dirname "$(realpath "$0")")
. "${script_home}/common.sh"

docker-compose -f "${script_home}"/docker-compose.yaml up --remove-orphans -d
