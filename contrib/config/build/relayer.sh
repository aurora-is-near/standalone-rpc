#! /bin/sh

NEAR_RPC="http://127.0.0.1:23030"
CHECK_INTERVAL=30  # Check every minute
MAX_RETRIES=3600   # Maximum number of retries (1 hour)

check_sync_status() {
    curl -s -X POST "${NEAR_RPC}" -H "Content-Type: application/json" -d '{
        "jsonrpc": "2.0",
        "method": "status",
        "params": [],
        "id": "dontcare"
    }' | docker run --rm -i mikefarah/yq:latest eval -r '.result.sync_info.syncing'
}

download_relayer_snapshot() {
    echo "Downloading relayer snapshot..."
    docker run --rm --pull=always \
        --init \
        -v "$(pwd)/${INSTALL_DIR}/data/relayer:/data" \
        -v "$(pwd)/${src_dir}/bin/download_rclone.sh:/download_rclone.sh" \
        --entrypoint=/bin/ash \
        rclone/rclone \
        -c "trap 'kill -TERM \$pid; exit 1' INT TERM; apk add --no-cache curl && chmod +x /download_rclone.sh && CHAIN_ID=${chain_id} SERVICE=relayer DATA_PATH=/data /download_rclone.sh & pid=\$! && wait \$pid"
}

stop_nearcore() {
    echo "Stopping nearcore..."
    docker stop nearcore
}

start_refiner() {
    echo "Starting refiner..."
    docker-compose -f "${INSTALL_DIR}/docker-compose.yaml" up -d refiner
}

start_relayer() {
    cmd="/usr/local/bin/relayer start -c /config/relayer.yaml"
    echo "Starting relayer: [$cmd]"
    $cmd &
}

main() {
    echo "Waiting for nearcore to sync..."
    retries=0

    while [ $retries -lt $MAX_RETRIES ]; do
        if [ "$(check_sync_status)" = "false" ]; then
            echo "NEAR node is synced!"
            download_relayer_snapshot
            stop_nearcore
            start_refiner
            start_relayer
            echo "Setup complete!"
            wait
            exit 0
        fi

        echo "NEAR node is still syncing... (attempt $((retries + 1))/$MAX_RETRIES)"
        retries=$((retries + 1))
        sleep $CHECK_INTERVAL
    done

    echo "Timeout waiting for NEAR node to sync"
    exit 1
}

main
