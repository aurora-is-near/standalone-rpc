#!/bin/sh

src_dir="contrib"
near_postfix="near"

network="mainnet"
near_source="nearcore" # nearcore or datalake
migrate_from=""
use_snapshots=1
download_workers=256

trap "echo Exited!; exit 2;" INT TERM

if [ ! -d "./${src_dir}" ]; then
	echo "Run ./install.sh from original git repository only!"
	exit 1
fi

. ./${src_dir}/bin/common.sh

install() {

  if [ "${network}" = "testnet" ]; then
	  near_postfix="testnet"
  fi

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

  if [ ! -f "${INSTALL_DIR}/config/relayer/relayer.json" ]; then
    echo "Generating relayer key..."
    docker run --rm --name near_keygen -v "$(pwd)/${INSTALL_DIR}"/config/relayer:/config:rw --entrypoint /bin/sh nearaurora/srpc2-relayer -c "/usr/local/bin/nearkey > /config/relayer.json"
    relayerName=$(cat "${INSTALL_DIR}/config/relayer/relayer.json" | grep account_id | cut -d\" -f4)
    sed "s/%%SIGNER%%/${relayerName}/" "${INSTALL_DIR}/config/relayer/relayer.yaml" > "${INSTALL_DIR}/config/relayer/relayer.yaml2" && \
    mv "${INSTALL_DIR}/config/relayer/relayer.yaml2" "${INSTALL_DIR}/config/relayer/relayer.yaml"
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

  if [ $use_snapshots -eq 1 ] || [ "x$migrate_from" != "x" ]; then
    latest=""
    if [ ! -f "${INSTALL_DIR}/.latest" ]; then
      echo Initial
      latest=$(curl -sSf https://snapshots.deploy.aurora.dev/snapshots/${network}-relayer2-latest)
      echo "${latest}" > "${INSTALL_DIR}/.latest"
    fi
    latest=$(cat "${INSTALL_DIR}/.latest")
    if [ ! -f "${INSTALL_DIR}/data/relayer/.version" ]; then
      echo "Downloading database snapshot ${latest}..."
      finish=0
      while [ ${finish} -eq 0 ]; do
        echo "Fetching, this can take some time..."
        curl -#Sf https://snapshots.deploy.aurora.dev/158c1b69348fda67682197791/${network}-relayer2-"${latest}"/data.tar | tar -xv -C "${INSTALL_DIR}/data/relayer/" >> "${INSTALL_DIR}/data/relayer/.lastfile" 2> /dev/null
        if [ -f "${INSTALL_DIR}/data/relayer/.version" ]; then
          finish=1
        fi
      done
    fi
  fi

  if [ ${near_source} = "nearcore" ]; then
    if [ "x$migrate_from" != "x" ]; then
      ln -s "$migrate_from/near" "${INSTALL_DIR}/near"
      ln -s "$migrate_from/engine" "${INSTALL_DIR}/engine"
    else
      mkdir -p "${INSTALL_DIR}/near" "${INSTALL_DIR}/engine" 2> /dev/null
      if [ ! -f "${INSTALL_DIR}/near/config.json" ]; then
        echo "Downloading default configuration..."
        curl -sSf -o "${INSTALL_DIR}/near/config.json" https://files.deploy.aurora.dev/"${network}"-new-rpc/config.json
      fi
      if [ ! -f "${INSTALL_DIR}/near/genesis.json" ]; then
        echo "Downloading genesis file..."
        curl -sSf -o "${INSTALL_DIR}/near/genesis.json.gz" https://files.deploy.aurora.dev/"${network}"-new-rpc/genesis.json.gz
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
      if [ $use_snapshots -eq 1 ] && [ ! -f "${INSTALL_DIR}/near/data/CURRENT" ]; then
        echo "Downloading near chain snapshot..."
        latest=$(docker run --rm --entrypoint /bin/sh nearaurora/srpc2-relayer -c "/usr/local/bin/s5cmd --no-sign-request --numworkers $download_workers cat s3://near-protocol-public/backups/${network}/rpc/latest")
        finish=0
        while [ ${finish} -eq 0 ]; do
          echo "Fetching, this can take some time..."
          docker run --rm --name near_downloader -v "$(pwd)/${INSTALL_DIR}"/near:/near:rw --entrypoint /bin/sh nearaurora/srpc2-relayer -c "/usr/local/bin/s5cmd --stat --no-sign-request cp s3://near-protocol-public/backups/${network}/rpc/"${latest}"/* /near/data/"
          if [ -f "${INSTALL_DIR}/near/data/CURRENT" ]; then
            finish=1
          fi
        done
      fi
    fi
    cp "./${src_dir}/config/docker/${network}_${near_source}.yaml" "${INSTALL_DIR}/docker-compose.yaml"
  elif [ ${near_source} = "datalake" ]; then
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
    sed "s|%%AWS%%|${AWS_SHARED_CREDENTIALS_FILE}|" "./${src_dir}/config/docker/${network}_${near_source}.yaml" > "${INSTALL_DIR}/docker-compose.yaml"
  else
    echo "Installation failed, invalid near data source. It should either be 'datalake' or 'nearcore' !"
    exit 1
  fi

  if [ $use_snapshots -eq 0 ] \
    || [ ${near_source} = "nearcore" -a -f "${INSTALL_DIR}/near/data/CURRENT" -a -f "${INSTALL_DIR}/data/relayer/.version" ] \
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
  printf '\nOptions\n'
  printf ' %s\t%s\n' "-n {mainnet|testnet}" "network to use, default is mainnet."
  printf ' %s\t%s\n' "-r {nearcore|datalake}" "near source for indexing, default is nearcore."
  printf ' %s\t\t%s\n\t\t\t%s\n' "-m {path}" "use the existing nearcore data at 'path' instead of downloading snapshots from scratch." \
  "This option is valid only if nearcore config is used, and '-s' option is ignored if this option is given."
  printf ' %s\t%s\n\t\t\t%s\n' "-w {number [1-256]}" "number of workers used for downloading near snapshots, default is 256." \
  "NOTE: On some OS and HW configurations, default number of workers may cause high CPU consumption during download."
  printf ' %s\t\t\t%s\n\t\t\t%s\n\t\t\t%s\n' "-s" "if specified then snapshots are ignored during installation, default downloads and uses snapshots." \
  "NOTE: Ignoring snapshots may cause refiner not to index near chain. This can only be a valid option" \
  "if near source is selected as datalake otherwise refiner will not be sync with near core from scratch."
  printf ' %s\t\t\t%s\n' "-v" "prints version"
  printf ' %s\t\t\t%s\n\t\t\t%s\n' "-h" "prints usage"
  printf 'Example\n%s\n\n' "./install.sh -n mainnet -r datalake -s"
}

while getopts ":n:r:m:w:svh" opt; do
  case "${opt}" in
    n)
      network="${OPTARG}"
      if [ "$network" != "mainnet" ] && [ "$network" != "testnet" ]; then
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
      use_snapshots=0
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

install