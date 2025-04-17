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

# The script downloads Aurora relayer and refiner snapshots using rclone for parallel downloads.
# It uses rclone for parallel downloads and retries failed downloads.
#
# Instructions:
# - Make sure you have rclone installed, e.g. using `sudo -v ; curl https://rclone.org/install.sh | sudo bash`
# - Set $CHAIN_ID to mainnet, testnet, 1313161554 or any other chain id (default: mainnet) 
# - Set $THREADS to the number of threads you want to use for downloading. Use 128 for 10Gbps, and 16 for 1Gbps (default: 128).
# - Set $TPSLIMIT to the maximum number of HTTP new actions per second. (default: 4096)
# - Set $BWLIMIT to the maximum bandwidth to use for download in case you want to limit it. (default: 10G)
# - Set $DATA_PATH to the path where you want to download the snapshot (default: ~/.near/data)
# - Set $SERVICE to the type of service you want to download (relayer or refiner)

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
: "${SERVICE:=relayer}"  # can be 'relayer' or 'refiner'

# Validate service type
if [ "$SERVICE" != "relayer" ] && [ "$SERVICE" != "refiner" ]; then
    echo "Error: Invalid service '$SERVICE'. Must be 'relayer' or 'refiner'"
    echo "Note: For nearcore snapshots, use download_near_snapshot.sh instead"
    exit 1
fi

# Get snapshot information
HTTP_URL="https://snapshots.deploy.aurora.dev"
PREFIX="4b7f2c9a134fdb58792083472/$CHAIN_ID/$SERVICE"
LATEST=$(curl -sSf "https://snapshots.deploy.aurora.dev/snapshots/${CHAIN_ID}-${SERVICE}-latest")

if [ -z "$LATEST" ]; then
    echo "Error: Failed to get latest snapshot for $SERVICE"
    exit 1
fi

echo "Latest $SERVICE snapshot block: $LATEST"

main() {
  mkdir -p "$DATA_PATH"
  echo "Downloading $SERVICE snapshot files..."

  # Standard rclone arguments for relayer/refiner
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
  RCLONE_ARGS="$RCLONE_ARGS --exclude LOG.old*"

  # Run rclone in background and capture PID
  # shellcheck disable=SC2086
  rclone copy $RCLONE_ARGS :http:$PREFIX/$LATEST/ $DATA_PATH &
  rclone_pid=$!

  # Wait for rclone to finish
  wait $rclone_pid || {
    echo "Error: rclone copy failed"
    exit 1
  }

  echo "$SERVICE snapshot download completed successfully!"
  echo "Snapshot downloaded to: $DATA_PATH"

  # Create a version file to indicate successful download
  echo "Downloaded from: $HTTP_URL/$PREFIX/$LATEST" > "$DATA_PATH/.version"
  echo "Download time: $(date)" >> "$DATA_PATH/.version"
  echo "Service: $SERVICE" >> "$DATA_PATH/.version"
}

main "$@"
