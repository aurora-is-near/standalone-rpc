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

# The script downloads the RPC snapshot from the FASTNEAR snapshots.
# It uses rclone for parallel downloads and retries failed downloads.
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

if [ -z "$PREFIX" ]; then
    case $SERVICE in
        near)
            HTTP_URL="https://snapshot.neardata.xyz"
            PREFIX="$CHAIN_ID/rpc"
            LATEST=$(curl -s "$HTTP_URL/$PREFIX/latest.txt")
            echo "Latest snapshot block: $LATEST"
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
  echo "Snapshot block: $LATEST"

  if [ "$SERVICE" = "near" ]; then
    FILES_PATH="/tmp/files.txt"
    curl -s "$HTTP_URL/$PREFIX/$LATEST/files.txt" -o $FILES_PATH
    EXPECTED_NUM_FILES=$(wc -l < $FILES_PATH)
    echo "Downloading $EXPECTED_NUM_FILES files with $THREADS threads"
  else
    echo "Downloading snapshot files..."
  fi

  RCLONE_ARGS="--tpslimit $TPSLIMIT"
  RCLONE_ARGS="$RCLONE_ARGS --bwlimit $BWLIMIT"
  RCLONE_ARGS="$RCLONE_ARGS --no-traverse"
  RCLONE_ARGS="$RCLONE_ARGS --transfers $THREADS"
  RCLONE_ARGS="$RCLONE_ARGS --checkers $THREADS"
  RCLONE_ARGS="$RCLONE_ARGS --buffer-size 128M"
  RCLONE_ARGS="$RCLONE_ARGS --http-url $HTTP_URL"
  RCLONE_ARGS="$RCLONE_ARGS --retries 10"
  RCLONE_ARGS="$RCLONE_ARGS --retries-sleep 1s"
  RCLONE_ARGS="$RCLONE_ARGS --low-level-retries 10"
  RCLONE_ARGS="$RCLONE_ARGS --progress"
  RCLONE_ARGS="$RCLONE_ARGS --stats 30s"
  RCLONE_ARGS="$RCLONE_ARGS --stats-one-line"
  RCLONE_ARGS="$RCLONE_ARGS --stats-unit bytes"
  RCLONE_ARGS="$RCLONE_ARGS --contimeout=1m"
  RCLONE_ARGS="$RCLONE_ARGS --disable-http2"

  if [ "$SERVICE" = "near" ]; then
    RCLONE_ARGS="$RCLONE_ARGS --files-from=$FILES_PATH"
  else
    RCLONE_ARGS="$RCLONE_ARGS --exclude LOG.old*"
  fi

  # Run rclone in background and capture PID
  # shellcheck disable=SC2086
  rclone copy $RCLONE_ARGS :http:$PREFIX/$LATEST/ $DATA_PATH &
  rclone_pid=$!

  # Wait for rclone to finish
  wait $rclone_pid || {
    echo "Error: rclone copy failed"
    exit 1
  }

  if [ "$SERVICE" = "near" ]; then
    ACTUAL_NUM_FILES=$(find $DATA_PATH -type f | wc -l)
    echo "Downloaded $ACTUAL_NUM_FILES files, expected $EXPECTED_NUM_FILES"

    if [ "$ACTUAL_NUM_FILES" -ne "$EXPECTED_NUM_FILES" ]; then
      echo "Error: Downloaded files count mismatch"
      exit 1
    fi
  fi
}

main "$@"
