#!/bin/ash

# Download nearcore snapshot from Aurora snapshot service
# Usage: download_near_snapshot.sh [CHAIN_ID] [DATA_PATH]

set -e

# Default values
CHAIN_ID=${1:-1313161554}
DATA_PATH=${2:-/root/.near/data}
THREADS=${THREADS:-256}
TPSLIMIT=${TPSLIMIT:-4096}
BWLIMIT=${BWLIMIT:-100M}

# Chain mapping
if [ "$CHAIN_ID" = "1313161555" ]; then
  CHAIN="near-testnet"
else
  CHAIN="near-mainnet"
fi

echo "Downloading nearcore snapshot for chain_id: $CHAIN_ID (mapped to: $CHAIN)"

# Create data directory
mkdir -p "$DATA_PATH"

# Fetch snapshot URL
L=$(curl -s "https://snapshots.aurora.dev/latest/$CHAIN/direct")

# Check if the URL was successfully fetched and is not empty
if [ -z "$L" ]; then
  echo "Error: Failed to fetch snapshot URL for chain $CHAIN (chain_id: $CHAIN_ID)"
  echo "The curl command returned an empty response"
  exit 1
fi

# Download index file
curl -s "$L/index" > /tmp/idx

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
  --bwlimit $BWLIMIT \
  :http: "$DATA_PATH" &
rclone_pid=$!

# Wait for rclone to finish
wait $rclone_pid || {
  echo "Error: rclone copy failed"
  rm -f /tmp/idx
  exit 1
}

echo "Nearcore snapshot download completed successfully!"
echo "Snapshot downloaded to: $DATA_PATH"

# Create a version file to indicate successful download
echo "Downloaded from: $L" > "$DATA_PATH/.version"
echo "Download time: $(date)" >> "$DATA_PATH/.version"
echo "Chain ID: $CHAIN_ID" >> "$DATA_PATH/.version"
echo "Aurora Chain: $CHAIN" >> "$DATA_PATH/.version"

# Clean up temporary index file
rm -f /tmp/idx

echo "Download completed successfully!" 