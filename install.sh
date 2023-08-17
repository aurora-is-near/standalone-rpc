#!/bin/sh

src_dir="contrib"
near_postfix="near"

network="mainnet"
near_network="mainnet"
silo_config_file=""
silo_name="mainnet"
near_source="nearcore" # nearcore or datalake
migrate_from=""
use_aurora_snapshot=1
use_near_snapshot=1
download_workers=256

trap "echo Exited!; exit 2;" INT TERM

if [ ! -d "./${src_dir}" ]; then
	echo "Run ./install.sh from original git repository only!"
	exit 1
fi

. ./${src_dir}/bin/common.sh

valid_silo_config() {
  if [ ! -f "$1" ]; then
      return 1
  fi
  while read -r config || [ -n "$config" ]; do
      if [ -n "$config" ] && [ "$config" != " " ] && ! beginswith "#" "$config"; then
          value=$(echo "$config" | cut -d ':' -f2- | awk '{$1=$1};1')
          if [ -n "$value" ] && [ "$value" != " " ] && [ -z "${value##*:*}" ]; then
              return 1
          fi
      fi
  done < "$1"
}

apply_silo_config() {
    silo_network=$(grep "SILO_NETWORK" "$1" | cut -d ':' -f2- | awk '{$1=$1};1')
    sed "s/%%SILO_NETWORK%%/${silo_network}/" "${INSTALL_DIR}/config/relayer/relayer.yaml" > "${INSTALL_DIR}/config/relayer/relayer.yaml2" && \
    mv "${INSTALL_DIR}/config/relayer/relayer.yaml2" "${INSTALL_DIR}/config/relayer/relayer.yaml"
    sed "s/%%SILO_NETWORK%%/${silo_network}/" "${INSTALL_DIR}/docker-compose.yaml" > "${INSTALL_DIR}/docker-compose.yaml2" && \
    mv "${INSTALL_DIR}/docker-compose.yaml2" "${INSTALL_DIR}/docker-compose.yaml"

    silo_chain_id=$(grep "SILO_CHAIN_ID" "$1" | cut -d ':' -f2- | awk '{$1=$1};1')
    sed "s/%%SILO_CHAIN_ID%%/${silo_chain_id}/" "${INSTALL_DIR}/config/refiner/refiner.json" > "${INSTALL_DIR}/config/refiner/refiner.json2" && \
    mv "${INSTALL_DIR}/config/refiner/refiner.json2" "${INSTALL_DIR}/config/refiner/refiner.json"
    sed "s/%%SILO_CHAIN_ID%%/${silo_chain_id}/" "${INSTALL_DIR}/config/relayer/relayer.yaml" > "${INSTALL_DIR}/config/relayer/relayer.yaml2" && \
    mv "${INSTALL_DIR}/config/relayer/relayer.yaml2" "${INSTALL_DIR}/config/relayer/relayer.yaml"

    silo_genesis=$(grep "SILO_GENESIS" "$1" | cut -d ':' -f2- | awk '{$1=$1};1')
    sed "s/%%SILO_GENESIS%%/${silo_genesis}/" "${INSTALL_DIR}/config/relayer/relayer.yaml" > "${INSTALL_DIR}/config/relayer/relayer.yaml2" && \
    mv "${INSTALL_DIR}/config/relayer/relayer.yaml2" "${INSTALL_DIR}/config/relayer/relayer.yaml"

    silo_from_block=$(grep "SILO_FROM_BLOCK" "$1" | cut -d ':' -f2- | awk '{$1=$1};1')
    sed "s/%%SILO_FROM_BLOCK%%/${silo_from_block}/" "${INSTALL_DIR}/config/relayer/relayer.yaml" > "${INSTALL_DIR}/config/relayer/relayer.yaml2" && \
    mv "${INSTALL_DIR}/config/relayer/relayer.yaml2" "${INSTALL_DIR}/config/relayer/relayer.yaml"
    sed "s/%%SILO_FROM_BLOCK%%/${silo_from_block}/" "${INSTALL_DIR}/docker-compose.yaml" > "${INSTALL_DIR}/docker-compose.yaml2" && \
    mv "${INSTALL_DIR}/docker-compose.yaml2" "${INSTALL_DIR}/docker-compose.yaml"

    filename=$(basename -- "$silo_config_file")
    silo_name=$(echo "${filename%%.*}" | tr '[:upper:]' '[:lower:]')

    engine_account=$(grep "SILO_ENGINE_ACCOUNT" "$silo_config_file" | cut -d ':' -f2- | awk '{$1=$1};1')
    sed "s/%%SILO_ENGINE_ACCOUNT%%/${engine_account}/" "${INSTALL_DIR}/config/refiner/refiner.json" > "${INSTALL_DIR}/config/refiner/refiner.json2" && \
    mv "${INSTALL_DIR}/config/refiner/refiner.json2" "${INSTALL_DIR}/config/refiner/refiner.json"

    if [ ${near_source} = "datalake" ]; then
      silo_datalake_network=$(to_upper_first "$silo_network")
      sed "s/%%SILO_DATALAKE_NETWORK%%/${silo_datalake_network}/" "${INSTALL_DIR}/config/refiner/refiner.json" > "${INSTALL_DIR}/config/refiner/refiner.json2" && \
      mv "${INSTALL_DIR}/config/refiner/refiner.json2" "${INSTALL_DIR}/config/refiner/refiner.json"
    fi
}

apply_nearcore_config() {
  if [ "x$migrate_from" != "x" ]; then
    ln -s "$migrate_from/near" "${INSTALL_DIR}/near"
    ln -s "$migrate_from/engine" "${INSTALL_DIR}/engine"
  else
    mkdir -p "${INSTALL_DIR}/near" "${INSTALL_DIR}/engine" 2> /dev/null
    if [ ! -f "${INSTALL_DIR}/near/config.json" ]; then
      echo "Downloading default configuration..."
      curl -sSf -o "${INSTALL_DIR}/near/config.json" https://files.deploy.aurora.dev/"${near_network}"-new-rpc/config.json
    fi
    if [ ! -f "${INSTALL_DIR}/near/genesis.json" ]; then
      echo "Downloading genesis file..."
      curl -sSf -o "${INSTALL_DIR}/near/genesis.json.gz" https://files.deploy.aurora.dev/"${near_network}"-new-rpc/genesis.json.gz
      echo "Extracting genesis file..."
      gzip -d "${INSTALL_DIR}/near/genesis.json.gz"
    fi
    if [ ! -f "${INSTALL_DIR}/near/node_key.json" ]; then
      echo "Generating node_key..."
      docker run --rm --name near_keygen -v "$(pwd)/${INSTALL_DIR}"/near:/near:rw --entrypoint /bin/sh nearaurora/srpc2-relayer -c "/usr/local/bin/nearkey node%.${near_postfix} > /near/node_key.json"
    fi
    if [ ! -f "${INSTALL_DIR}/near/validator_key.json" ]; then
      echo "Generating validator_key..."
      docker run --rm --name near_keygen -v "$(pwd)/${INSTALL_DIR}"/near:/near:rw --entrypoint /bin/sh nearaurora/srpc2-relayer -c "/usr/local/bin/nearkey node%.${near_postfix} > /near/validator_key.json"
    fi
    if [ $use_near_snapshot -eq 1 ] && [ ! -f "${INSTALL_DIR}/near/data/CURRENT" ]; then
      echo "Downloading near chain snapshot..."
      latest=$(docker run --rm --entrypoint /bin/sh nearaurora/srpc2-relayer -c "/usr/local/bin/s5cmd --no-sign-request --numworkers $download_workers cat s3://near-protocol-public/backups/${near_network}/rpc/latest")
      finish=0
      while [ ${finish} -eq 0 ]; do
        echo "Fetching, this can take some time..."
        docker run --rm --name near_downloader -v "$(pwd)/${INSTALL_DIR}"/near:/near:rw --entrypoint /bin/sh nearaurora/srpc2-relayer -c "/usr/local/bin/s5cmd --stat --no-sign-request cp s3://near-protocol-public/backups/${near_network}/rpc/"${latest}"/* /near/data/"
        if [ -f "${INSTALL_DIR}/near/data/CURRENT" ]; then
          finish=1
        fi
      done
    fi
  fi
}

apply_datalake_config() {
  if [ "x$AWS_SHARED_CREDENTIALS_FILE" = "x" ]; then
    echo "Installation failed, environment variable AWS_SHARED_CREDENTIALS_FILE is needed for datalake config." \
         "Please set environment variable AWS_SHARED_CREDENTIALS_FILE for [$USER] user or run installer as 'AWS_SHARED_CREDENTIALS_FILE={path to AWS credentials file} ./install.sh'"
    echo "For more details, also see https://docs.aws.amazon.com/sdkref/latest/guide/file-location.html"
    exit 1
  fi
  if [ ! -f "$AWS_SHARED_CREDENTIALS_FILE" ]; then
    echo "Installation failed, datalake config requires AWS account." \
         "Create [$AWS_SHARED_CREDENTIALS_FILE] file and run install script again!"
    exit 1
  fi
  sed "s|%%AWS%%|${AWS_SHARED_CREDENTIALS_FILE}|" "${INSTALL_DIR}/docker-compose.yaml" > "${INSTALL_DIR}/docker-compose.yaml2"
  mv "${INSTALL_DIR}/docker-compose.yaml2" "${INSTALL_DIR}/docker-compose.yaml"
}

install() {

  if [ -f "${VERSION_FILE}" ]; then
    echo "There is already an Aurora Standalone RPC installation running or an unfinished installation exists"
    if confirmed "To continue with installation, you have to first uninstall. Would you like to uninstall?"; then
      ./uninstall.sh
    else
      exit 1
    fi
  fi

  echo "Installing" && version | tee "${VERSION_FILE}"

  set -e

  mkdir -p  "${INSTALL_DIR}/data/relayer" \
            "${INSTALL_DIR}/data/refiner" \
            "${INSTALL_DIR}/config/relayer" \
            "${INSTALL_DIR}/config/refiner" \
            "${INSTALL_DIR}/config/nginx" 2> /dev/null

  if [ ! -f "${INSTALL_DIR}/config/relayer/relayer.yaml" ]; then
    cp "./${src_dir}/config/relayer/${network}.yaml" "${INSTALL_DIR}/config/relayer/relayer.yaml"
  fi

  if [ ! -f "${INSTALL_DIR}/config/relayer/filter.yaml" ]; then
    cp "./${src_dir}/config/relayer/filter.yaml" "${INSTALL_DIR}/config/relayer/filter.yaml"
  fi

  if [ ! -f "${INSTALL_DIR}/config/refiner/refiner.json" ]; then
    cp "./${src_dir}/config/refiner/${network}_${near_source}.json" "${INSTALL_DIR}/config/refiner/refiner.json"
  fi

  if [ ! -f "${INSTALL_DIR}/config/nginx/endpoint.conf" ]; then
    cp "./${src_dir}/config/nginx/${network}.conf" "${INSTALL_DIR}/config/nginx/endpoint.conf"
  fi

  if [ ! -f "${INSTALL_DIR}/docker-compose.yaml" ]; then
    cp "./${src_dir}/config/docker/${network}_${near_source}.yaml" "${INSTALL_DIR}/docker-compose.yaml"
  fi

  if [ "${network}" = "silo" ]; then
    apply_silo_config "$silo_config_file"
    near_network="$silo_network"
  else
    near_network="$network"
  fi

  if [ "${near_source}" = "nearcore" ]; then
    apply_nearcore_config
  else
    apply_datalake_config
  fi

  if [ $use_aurora_snapshot -eq 1 ] || [ "x$migrate_from" != "x" ]; then
    latest=""
    if [ ! -f "${INSTALL_DIR}/.latest" ]; then
      echo Initial
      latest=$(curl -sSf https://snapshots.deploy.aurora.dev/snapshots/${near_network}_${silo_name}-relayer-latest)
      echo "${latest}" > "${INSTALL_DIR}/.latest"
    fi
    latest=$(cat "${INSTALL_DIR}/.latest")
    if [ ! -f "${INSTALL_DIR}/data/relayer/.version" ]; then
      echo "Downloading database snapshot ${latest}..."
      finish=0
      while [ ${finish} -eq 0 ]; do
        echo "Fetching, this can take some time..."
        curl -#Sf https://snapshots.deploy.aurora.dev/158c1b69348fda67682197791/${near_network}_${silo_name}-relayer-"${latest}"/data.tar | tar -xv -C "${INSTALL_DIR}/data/relayer/" >> "${INSTALL_DIR}/data/relayer/.lastfile" 2> /dev/null
        if [ -f "${INSTALL_DIR}/data/relayer/.version" ]; then
          finish=1
        fi
      done
    fi
  fi


  if [ ! -f "${INSTALL_DIR}/config/relayer/relayer.json" ]; then
    echo "Generating relayer key..."
    docker run --rm --name near_keygen -v "$(pwd)/${INSTALL_DIR}"/config/relayer:/config:rw --entrypoint /bin/sh nearaurora/srpc2-relayer -c "/usr/local/bin/nearkey > /config/relayer.json"
  fi

  account_id=$(grep "account_id" "${INSTALL_DIR}/config/relayer/relayer.json" | cut -d\" -f4)
  sed "s/%%SIGNER%%/${account_id}/" "${INSTALL_DIR}/config/relayer/relayer.yaml" > "${INSTALL_DIR}/config/relayer/relayer.yaml2" && \
  mv "${INSTALL_DIR}/config/relayer/relayer.yaml2" "${INSTALL_DIR}/config/relayer/relayer.yaml"

  if [ $use_aurora_snapshot -eq 0 -a $use_near_snapshot -eq 0 ] \
    || [ $use_near_snapshot -eq 1 -a ${near_source} = "nearcore" -a -f "${INSTALL_DIR}/near/data/CURRENT" -a -f "${INSTALL_DIR}/data/relayer/.version" ] \
    || [ ${near_source} = "datalake" -a -f "${INSTALL_DIR}/data/relayer/.version" ]; then
    echo "Setup complete [${network}, ${near_source}]"
  fi

  set +e

  if [ "x$migrate_from" != "x" ]; then
    "$migrate_from"/stop.sh
  fi

  cp "./${src_dir}/bin/start.sh" "${INSTALL_DIR}/start.sh"
  cp "./${src_dir}/bin/stop.sh" "${INSTALL_DIR}/stop.sh"
  cp "./${src_dir}/bin/common.sh" "${INSTALL_DIR}/common.sh"
  cp "./${src_dir}/bin/support.sh" "${INSTALL_DIR}/support.sh"

  echo "Starting..."
  ./"${INSTALL_DIR}"/start.sh
}

version() {
  if [ ! -f "${VERSION_FILE}" ]; then
    echo "Aurora Standalone RPC"
    branch=$(git rev-parse --abbrev-ref HEAD) && echo "branch: $branch" \
    && commit=$(git rev-parse HEAD) && echo "commit: $commit" \
    && tag=$(git describe --exact-match "$commit") 2>/dev/null && echo "tag: $tag"
  else
    cat "${VERSION_FILE}"
  fi
}

usage() {
  printf '\nUsage: %s [options]' "$(basename "$0")"
  printf '\n\nOptions\n'
  printf ' %s\t%s\n\n' "-n {mainnet|testnet|silo}" "network to use, default is mainnet."
  printf ' %s\t\t\t%s\n\t\t\t\t%s\n\n' "-f {path}" "for silo networks, this is the path to your silo configuration file." \
  "This option is valid only if silo network is used, and '-s' option is ignored if this option is given."
  printf ' %s\t\t%s\n\n' "-r {nearcore|datalake}" "near source for indexing, default is nearcore."
  printf ' %s\t\t\t%s\n\t\t\t\t%s\n\n' "-m {path}" "use the existing nearcore data at 'path' instead of downloading snapshots from scratch." \
  "This option is valid only if nearcore config is used, and '-s' option is ignored if this option is given."
  printf ' %s\t\t%s\n\t\t\t\t%s\n\n' "-w {number [1-256]}" "number of workers used for downloading near snapshots, default is 256." \
  "NOTE: On some OS and HW configurations, default number of workers may cause high CPU consumption during download."
  printf ' %s\t\t\t\t%s\n\t\t\t\t%s\n\t\t\t\t%s\n\n' "-s" "if specified then snapshots are ignored during installation, default downloads and uses snapshots." \
  "NOTE: Ignoring snapshots may cause refiner not to index near chain. This can only be a valid option" \
  "if near source is selected as datalake otherwise refiner will not be sync with near core from scratch."
  printf ' %s\t\t\t\t%s\n\n' "-v" "prints version"
  printf ' %s\t\t\t\t%s\n\n' "-h" "prints usage"
  printf 'Examples\n'
  printf ' %s\t\t-> %s\n\n' "./install.sh -n mainnet -r datalake -s" "use mainnet with near data lake but do not download snapshots"
  printf ' %s\t\t-> %s\n\n' "./install.sh -n silo -f ./silo.conf" "use sile network whose config is defined in silo.conf, near source for indexing is nearcore"
}

while getopts ":n:r:m:f:w:svh" opt; do
  case "${opt}" in
    n)
      network="${OPTARG}"
      if [ "${network}" = "testnet" ]; then
        near_postfix="testnet"
      elif [ "${network}" != "mainnet" ] && [ "${network}" != "silo" ] ; then
        echo "Invalid Value: -${opt} cannot be '${OPTARG}'"
        usage
        exit 1
      fi
      ;;
    r)
      near_source="${OPTARG}"
      if [ "$near_source" != "nearcore" ] && [ "$near_source" != "datalake" ]; then
        echo "Invalid Value: -${opt} cannot be '${OPTARG}'"
        usage
        exit 1
      fi
      ;;
    w)
      download_workers="${OPTARG}"
      if [ "$download_workers" -lt 1 ] || [ "$download_workers" -gt 256 ]; then
        echo "Invalid Value: -${opt} cannot be '${OPTARG}'"
        usage
        exit 1
      fi
      ;;
    m)
      migrate_from=$(realpath "${OPTARG}")
      if [ ! -d "$migrate_from/near" ] || [ ! -d "$migrate_from/engine" ]; then
        echo "Invalid Value: path(s) '${OPTARG}/near' or(and) '${OPTARG}/engine' not exist"
        usage
        exit 1
      fi
      ;;
    s)
      use_aurora_snapshot=0
      use_near_snapshot=0
      ;;
    f)
      silo_config_file="${OPTARG}"
      ;;
    v)
      version
      exit 0
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

if [ "${network}" = "silo" ] && ! valid_silo_config "$silo_config_file"; then
  echo "Invalid silo config, $silo_config_file. For more information, see template config ./${src_dir}/silo/template.conf"
  exit 1
fi

install