#!/bin/ash

# Download Aurora snapshots from Aurora snapshot service
# Usage: download_snapshot.sh [NETWORK] [SERVICE] [DATA_PATH]

set -e

# Better signal handling
cleanup() {
    local signal=$1
    echo "Received signal $signal, cleaning up..."
    if [ -n "$rclone_pid" ]; then
        kill -TERM "$rclone_pid" 2>/dev/null || true
    fi
    rm -f /tmp/idx
    exit 1
}

trap 'cleanup INT' INT
trap 'cleanup TERM' TERM

# Default values
NETWORK=${NETWORK:-mainnet}
SERVICE=${SERVICE:-relayer}
DATA_PATH=${DATA_PATH:-/data}
THREADS=${THREADS:-128}
TPSLIMIT=${TPSLIMIT:-4096}
BWLIMIT=${BWLIMIT:-10G}

# Validate service type
if [ "$SERVICE" != "relayer" ] && [ "$SERVICE" != "refiner" ] && [ "$SERVICE" != "nearcore" ]; then
    echo "Error: Invalid service '$SERVICE'. Must be 'relayer', 'refiner', or 'nearcore'"
    exit 1
fi

# Network validation
if [ "$NETWORK" != "mainnet" ] && [ "$NETWORK" != "testnet" ]; then
    echo "Error: Invalid network '$NETWORK'. Must be 'mainnet' or 'testnet'"
    exit 1
fi

echo "Downloading $SERVICE snapshot for network: $NETWORK"

# Create data directory
mkdir -p "$DATA_PATH"

# Fetch snapshot URL using new format
L=$(curl -s "https://snapshots.aurora.dev/latest/$NETWORK/$SERVICE/full/uncompressed")

# Check if the URL was successfully fetched and is not empty
if [ -z "$L" ]; then
    echo "Error: Failed to fetch snapshot URL for $SERVICE (network: $NETWORK)"
    echo "The curl command returned an empty response"
    exit 1
fi

echo "Snapshot URL: $L"

# Download index file
curl -s "$L/index" > /tmp/idx

# Check if index file was downloaded successfully
if [ ! -s /tmp/idx ]; then
    echo "Error: Failed to download index file from $L/index"
    exit 1
fi

# Run rclone with optimized settings for Aurora snapshots
echo "Starting rclone download with optimized settings..."
echo "Using $THREADS threads for parallel downloads"

# shellcheck disable=SC2086
rclone copy \
  --buffer-size 128M \
  --transfers $THREADS \
  --tpslimit $TPSLIMIT \
  --retries 20 \
  --retries-sleep 1s \
  --low-level-retries 10 \
  --multi-thread-streams 1 \
  --no-traverse \
  --http-url "$L/data" \
  --files-from /tmp/idx \
  --checkers $THREADS \
  --max-backlog 1000000 \
  --progress \
  --stats-one-line \
  --stats 30s \
  --bwlimit $BWLIMIT \
  :http: "$DATA_PATH" &
rclone_pid=$!

# Wait for rclone to finish
wait $rclone_pid || {
    echo "Error: rclone copy failed"
    rm -f /tmp/idx
    exit 1
}

echo "$SERVICE snapshot download completed successfully!"
echo "Snapshot downloaded to: $DATA_PATH"

# Create a version file to indicate successful download
echo "Downloaded from: $L" > "$DATA_PATH/.version"
echo "Download time: $(date)" >> "$DATA_PATH/.version"
echo "Service: $SERVICE" >> "$DATA_PATH/.version"
echo "Network: $NETWORK" >> "$DATA_PATH/.version"

# Clean up temporary index file
rm -f /tmp/idx

echo "Download completed successfully!" 