#!/bin/sh

script_home=$(dirname "$(realpath "$0")")
. "$script_home/common.sh"

build_path="$script_home/../config/build"
build_context="$build_path"
build_stage="build"

push=0
key=""

# build_one {image} {version[:overwrite_version]} {tag prefix}
build_one() {
  echo "Building $1 $2 ..."
  if [ -f "$key" ]; then
   key=$(bzip2 -cz "$key" | base64 | tr -d "\n")
  fi

  v=$(echo "$2" | cut -d':' -f1)
  ov=$(echo "$2" | cut -d':' -f2)
  if [ "x$ov" = "x" ]; then
    ov=v
  fi

  docker build \
    --build-arg STAGE="$build_stage" \
    --build-arg BUILD_ID="$2" \
    --build-arg VERSION="$v" \
    --build-arg OVERWRITE_VERSION="$ov" \
    --build-arg KEY="${key}" \
    --no-cache -f "${build_path}/Dockerfile.$1" -t "$3:$ov" "${build_context}"
    docker image prune --filter label="stage=$build_stage" --filter label="build=$ov" --force
    docker tag "$3:$ov" "$3:latest"
  if [ $push -eq 1 ]; then
    push "$3" "$ov"
    push "$3" "latest"
  fi
}

# push {tag prefix} {version}
push() {
  echo "Pushing $1:$2 ..."
  docker push "$1:$2"
}

# build [images ...]
build() {
  if [ $# -eq 0 ]; then
    set -- "relayer" "refiner"
  fi
  for i in "$@"; do
    if [ "$i" != "relayer" ] && [ "$i" != "refiner" ]; then
      echo "Invalid Image Name: [$i]"
      usage
      exit 1
    fi
    eval "version=\$${i}_version"
    if [ "x$version" = "x" ]; then
      echo "Unknown Version: [$i] version should be specified!"
      usage
      exit 1
    fi
    eval "tag=\$DOCKER_TAG_$(echo ${i} | tr [:lower:] [:upper:])"
    build_one "$i" "$version" "$tag"
  done
}

usage() {
  printf '\nUsage:\t\t%s [Options] [Images ...]' "$(basename "$0")"
  printf '\n\nImages:\t\t%s\n' "default all, if not specified"
  set -- "relayer" "refiner"
  for i in "$@"; do
    printf '  %s\n' "$i"
  done
  printf '\nOptions:\n'
  printf '  %s\t\t%s\n' "-v" "relayer version, mandatory option to build relayer"
  printf '  %s\t\t%s\n' "-r" "refiner version, mandatory option to build refiner"
  printf '  %s\t\t%s\n' "-p" "push images to docker repository, default no push"
  printf '  %s\t\t%s\n' "-h" "prints usage"
  printf '\nExamples:\n'
  printf '  %s\n\n' "./build.sh -r v0.18.0 -v v2.0.0 -p"
}

while getopts ":v:r:k:ph" opt; do
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
    h)
      usage
      exit 0
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

build "$@"
