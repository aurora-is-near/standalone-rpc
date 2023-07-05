#!/bin/sh

old_config="/config/relayer.yaml"
tmp_config="/config/relayer.yaml.tmp"
tmp_file="/tmp_File"

echo "updating relayer config..."

# backup old config
cp $old_config $tmp_config

# merge new partial config to old config
yq '. *= load("/update/v2.1.0/new_rpcNode_config.yaml")' "$old_config" > "$tmp_file" && mv "$tmp_file" "$old_config"

# set values of deprecated config keys as values of new config keys
yq '.rpcNode.geth.HTTPHost as $x | .rpcNode.httpHost = $x' "$old_config" > "$tmp_file" && mv "$tmp_file" "$old_config"
yq '.rpcNode.geth.HTTPPort as $x | .rpcNode.httpPort = $x' "$old_config" > "$tmp_file" && mv "$tmp_file" "$old_config"
yq '.rpcNode.geth.HTTPPathPrefix as $x | .rpcNode.httpPathPrefix = $x' "$old_config" > "$tmp_file" && mv "$tmp_file" "$old_config"
yq '.rpcNode.geth.HTTPCors as $x | .rpcNode.httpCors = $x' "$old_config" > "$tmp_file" && mv "$tmp_file" "$old_config"
yq '.rpcNode.geth.WSHost as $x | .rpcNode.wsHost = $x' "$old_config" > "$tmp_file" && mv "$tmp_file" "$old_config"
yq '.rpcNode.geth.WSPort as $x | .rpcNode.wsPort = $x' "$old_config" > "$tmp_file" && mv "$tmp_file" "$old_config"
yq '.rpcNode.geth.WSPathPrefix as $x | .rpcNode.wsPathPrefix = $x' "$old_config" > "$tmp_file" && mv "$tmp_file" "$old_config"

# delete old config keys
yq 'del(.rpcNode.geth)' "$old_config" > "$tmp_file" && mv "$tmp_file" "$old_config"
