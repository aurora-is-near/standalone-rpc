#!/bin/sh

old_config="/config/relayer.yaml"
tmp_config="/config/relayer.yaml.tmp"
tmp_file="/tmp_File"

echo "updating relayer config..."

# backup old config
cp $old_config $tmp_config

# merge new partial config to old config
nearNetwork=$(yq '.endpoint.engine.nearNetworkID' "$old_config")
if [ "$nearNetwork" = "testnet" ]; then
  yq '. *= load("/update/v2.1.3/new_engine_config_testnet.yaml")' "$old_config" > "$tmp_file" && mv "$tmp_file" "$old_config"
else
  yq '. *= load("/update/v2.1.3/new_engine_config_mainnet.yaml")' "$old_config" > "$tmp_file" && mv "$tmp_file" "$old_config"
fi

# update value of endpoint.engine.nearNodeURL with http://srpc2-refiner:3030
yq '.endpoint.engine.nearNodeURL="http://srpc2-refiner:3030"' "$old_config" > "$tmp_file" && mv "$tmp_file" "$old_config"

# delete old config keys
yq 'del(.rpcNode.geth)' "$old_config" > "$tmp_file" && mv "$tmp_file" "$old_config"
