#!/bin/ash
set -e

# Better signal handling
cleanup() {
    local signal=$1
    echo "Received signal $signal, cleaning up..."
    if [ -n "$wget_pid" ]; then
        kill -TERM "$wget_pid" 2>/dev/null || true
    fi
    exit 1
}

trap 'cleanup INT' INT
trap 'cleanup TERM' TERM

# The script downloads the nearcore snapshot from Aurora snapshots.
# It uses wget to download and zstd to decompress the snapshot.
#
# Instructions:
# - Set $NEAR_NETWORK to mainnet or testnet (default: mainnet)
# - Set $DATA_PATH to the path where you want to download the snapshot (default: ~/.near/data)

: "${NEAR_NETWORK:=mainnet}"
: "${DATA_PATH:=~/.near/data}"

main() {
  mkdir -p "$DATA_PATH"
  
  # Determine the snapshot URL based on network
  if [ "$NEAR_NETWORK" = "testnet" ]; then
    SNAPSHOT_URL="https://snapshots.aurora.dev/latest/near-testnet"
  else
    SNAPSHOT_URL="https://snapshots.aurora.dev/latest/near-mainnet"
  fi
  
  echo "Downloading nearcore snapshot for network: $NEAR_NETWORK"
  echo "Snapshot URL: $SNAPSHOT_URL"
  echo "Target directory: $DATA_PATH"
  echo "This may take a while depending on your internet connection..."
  
  # Download and extract the snapshot
  # Using wget to download and pipe to zstd for decompression, then tar to extract
  wget -O - "$SNAPSHOT_URL" | zstd -d | tar -xf - -C "$DATA_PATH" &
  wget_pid=$!
  
  # Wait for wget to finish
  wait $wget_pid || {
    echo "Error: Failed to download nearcore snapshot"
    exit 1
  }
  
  echo "Nearcore snapshot download completed successfully!"
  echo "Snapshot extracted to: $DATA_PATH"
  
  # Create a version file to indicate successful download
  echo "Downloaded from: $SNAPSHOT_URL" > "$DATA_PATH/.version"
  echo "Download time: $(date)" >> "$DATA_PATH/.version"
}

main "$@" 