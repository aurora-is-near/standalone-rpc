#!/bin/sh

script_home=$(dirname "$(realpath "$0")")
. "$script_home/common.sh"

build_path="$script_home/../config/build"
build_context="$build_path"
build_stage="build"

push=0
key=""
relayer_version=""
refiner_version="v0.17.0"

build() {
  if [ "x$relayer_version" = "x" ]; then
    echo "relayer version should be specified!"
    usage
    exit 1
  fi

  if [ "x$refiner_version" = "x" ]; then
    echo "refiner version should be specified!"
    usage
    exit 1
  fi

  # for private repo
  if [ -f "$key" ]; then
    key=$(bzip2 -cz "$key" | base64 | tr -d "\n")
  fi

  docker build \
  --build-arg STAGE="$build_stage" \
  --build-arg BUILD_ID="${relayer_version}" \
  --build-arg VERSION="${relayer_version}" \
  --build-arg KEY="${key}" \
  --no-cache -f "${build_path}/Dockerfile.relayer" -t "${DOCKER_TAG_RELAYER}:${relayer_version}" "${build_context}"
  docker image prune --filter label=stage="$build_stage" --filter label=build="${relayer_version}" --force
  docker tag "${DOCKER_TAG_RELAYER}:${relayer_version}" "${DOCKER_TAG_RELAYER}:latest"

  docker build \
  --build-arg STAGE="$build_stage" \
  --build-arg BUILD_ID="${refiner_version}" \
  --build-arg VERSION="${refiner_version}" \
  --no-cache -f "${build_path}/Dockerfile.refiner" -t "${DOCKER_TAG_REFINER}:${refiner_version}" "${build_context}"
  docker image prune --filter label=stage="$build_stage" --filter label=build="${refiner_version}" --force
  docker tag "${DOCKER_TAG_REFINER}:${refiner_version}" "${DOCKER_TAG_REFINER}:latest"
}

push() {
  if [ $push -eq 1 ]; then
    docker push "${DOCKER_TAG_RELAYER}":latest
    docker push "${DOCKER_TAG_RELAYER}":"${relayer_version}"
    docker push "${DOCKER_TAG_REFINER}":latest
    docker push "${DOCKER_TAG_REFINER}":"${refiner_version}"
  fi
}

usage() {
  # TODO: add usage
  echo "TODO usage..."
}

while getopts ":v:r:k:p" opt; do
  case "${opt}" in
    v)
      relayer_version="${OPTARG}"
      ;;
    r)
      refiner_version="${OPTARG}"
      ;;
    k)
      key="${OPTARG}"
      ;;
    p)
      push=1
      ;;
    \?)
      echo "Invalid Option: -${OPTARG}" 1>&2
      usage
      exit 1
      ;;
    :)
      echo "Invalid Option: -${OPTARG} requires an argument" 1>&2
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

build
if [ $push -eq 1 ]; then
  push
fi