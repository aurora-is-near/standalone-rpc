#!/bin/sh

script_home=$(dirname "$(realpath "$0")")
. "${script_home}/common.sh"

height=""
cmd="/usr/local/bin/aurora-refiner -c /config/refiner.json run"

if [ "x$curr_version" != "x" ] && [ "$long_version" != "$curr_version" ]; then
  echo "successfully updated to $long_version"
  echo "$long_version $(date)" >> $version_log_file
fi

while [ "x$height" = "x" ]; do
  # get latest block from relayer to start refiner from specific height
  resp=$(curl http://srpc2-relayer:8545 -X POST -H "Content-Type: application/json" \
             -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params": [],"id":1}' 2>/dev/null)
  if test $? -eq 0; then
    echo "received response from relayer: $resp"
    result=$(echo "$resp" | jq -r '.result' 2>/dev/null)
    if test $? -eq 0 && { [ "0x" = "$(echo "$result" | cut -c-2)" ] || [ "0X" = "$(echo "$result" | cut -c-2)" ]; }; then
      height=$(printf %d "$result" 2>/dev/null)
      if test $? -eq 0; then
        if [ $height -gt 0 ]; then
          # start refiner with received height
          cmd="$cmd --height $height"
          break
        fi
      fi
    fi
    error=$(echo "$resp" | jq -r '.error.message' 2>/dev/null)
    if test $? -eq 0 && [ "$error" = "record not found in DB" ]; then
      near_config=$(grep DataLake /config/refiner.json)
      if [ "x$near_config" != "x" ]; then
        # if datalake config and there is no record in DB, start refiner without height. i.e: starts from earliest block
        # in AWS S3 where near datalake resides
        break
      fi
      # If refiner is configured to index from nearcore, then there is no way refiner can index anything earlier than
      # 2 epochs of the current block height from the near core, so keep waiting if the received height is 0.
      # This can happen if relayer is started without any snapshots, possible solution;
      #   - manually wiring relayer data or let installation downloads relayer snapshots
      #   - and restart relayer
    fi
  fi
  echo "waiting for relayer response for block height..."
  sleep 5
done

echo "starting refiner: [$cmd]"

$cmd