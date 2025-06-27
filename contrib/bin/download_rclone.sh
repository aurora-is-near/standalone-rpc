#!/bin/ash
set -e

# Better signal handling
cleanup() {
    local signal=$1
    echo "Received signal $signal, cleaning up..."
    if [ -n "$rclone_pid" ]; then
        kill -TERM "$rclone_pid" 2>/dev/null || true
    fi
    exit 1
}

trap 'cleanup INT' INT
trap 'cleanup TERM' TERM

# The script downloads snapshots using rclone for parallel downloads and retries failed downloads.
#
# Instructions:
# - Make sure you have rclone installed, e.g. using `sudo -v ; curl https://rclone.org/install.sh | sudo bash`
# - Set $CHAIN_ID to  mainnet, testnet, 1313161554 or any other chain id (default: mainnet) 
# - Set $THREADS to the number of threads you want to use for downloading. Use 128 for 10Gbps, and 16 for 1Gbps (default: 128).
# - Set $TPSLIMIT to the maximum number of HTTP new actions per second. (default: 4096)
# - Set $BWLIMIT to the maximum bandwidth to use for download in case you want to limit it. (default: 10G)
# - Set $DATA_PATH to the path where you want to download the snapshot (default: ~/.near/data)
# - Set $HTTP_URL to the base URL for downloading snapshots
# - Set $SERVICE to the type of service you want to download (default: near)
# - Set $PREFIX to the specific prefix for the service
# - Set $NEAR_NETWORK to mainnet or testnet for near service (default: mainnet)

if ! type rclone >/dev/null 2>&1
then
    echo "rclone is not installed. Please install it and try again."
    exit 1
fi

: "${CHAIN_ID:=1313161554}"
: "${THREADS:=128}"
: "${TPSLIMIT:=4096}"
: "${BWLIMIT:=10G}"
: "${DATA_PATH:=~/.near/data}"
: "${SERVICE:=near}"  # can be 'near', 'relayer', or 'refiner'
: "${HTTP_URL:=}"
: "${PREFIX:=}"
: "${NEAR_NETWORK:=mainnet}"

# Shared rclone arguments for all services
get_rclone_args() {
    local args=""
    args="$args --progress"
    args="$args --stats 30s"
    args="$args --stats-one-line"
    args="$args --stats-unit bytes"
    args="$args --retries 10"
    args="$args --retries-sleep 1s"
    args="$args --low-level-retries 10"
    args="$args --contimeout=1m"
    args="$args --bwlimit $BWLIMIT"
    echo "$args"
}

if [ -z "$PREFIX" ]; then
    case $SERVICE in
        near)
            HTTP_URL="https://snapshots.aurora.dev"
            PREFIX="latest"
            LATEST="near-$NEAR_NETWORK"
            echo "Downloading nearcore snapshot for network: $NEAR_NETWORK"
            ;;
        relayer)
            HTTP_URL="https://snapshots.deploy.aurora.dev"
            PREFIX="4b7f2c9a134fdb58792083472/$CHAIN_ID/relayer"
            LATEST=$(curl -sSf https://snapshots.deploy.aurora.dev/snapshots/${CHAIN_ID}-relayer-latest)
            ;;
        refiner)
            HTTP_URL="https://snapshots.deploy.aurora.dev"
            PREFIX="4b7f2c9a134fdb58792083472/$CHAIN_ID/refiner"
            LATEST=$(curl -sSf https://snapshots.deploy.aurora.dev/snapshots/${CHAIN_ID}-refiner-latest)
            ;;
        *)
            echo "Invalid service: $SERVICE"
            exit 1
            ;;
    esac
fi

main() {
  mkdir -p "$DATA_PATH"
  
  if [ "$SERVICE" = "near" ]; then
    echo "Downloading nearcore snapshot for network: $NEAR_NETWORK"
    
    # For near service, use wget which follows redirects automatically
    echo "Downloading and extracting snapshot in one pass..."
    wget -O - "$HTTP_URL/$PREFIX/$LATEST" | zstd -d --verbose | tar -xf - -C "$DATA_PATH"
    
  else
    echo "Downloading snapshot files..."
    
    # Additional args for directory copying
    local rclone_args=$(get_rclone_args)
    rclone_args="$rclone_args --tpslimit $TPSLIMIT"
    rclone_args="$rclone_args --no-traverse"
    rclone_args="$rclone_args --transfers $THREADS"
    rclone_args="$rclone_args --checkers $THREADS"
    rclone_args="$rclone_args --buffer-size 128M"
    rclone_args="$rclone_args --http-url $HTTP_URL"
    rclone_args="$rclone_args --disable-http2"
    rclone_args="$rclone_args --exclude LOG.old*"

    # Run rclone in background and capture PID
    # shellcheck disable=SC2086
    rclone copy $rclone_args :http:$PREFIX/$LATEST/ $DATA_PATH &
    rclone_pid=$!

    # Wait for rclone to finish
    wait $rclone_pid || {
      echo "Error: rclone copy failed"
      exit 1
    }
  fi

  if [ "$SERVICE" = "near" ]; then
    echo "Nearcore snapshot download completed successfully!"
    echo "Snapshot extracted to: $DATA_PATH"
    
    # Create a version file to indicate successful download
    echo "Downloaded from: $HTTP_URL/$PREFIX/$LATEST" > "$DATA_PATH/.version"
    echo "Download time: $(date)" >> "$DATA_PATH/.version"
  fi
}

main "$@"
