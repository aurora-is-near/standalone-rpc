#!/bin/sh

tmp_config="/config/relayer.yaml.tmp"

echo "deleting old relayer config..."

# everything is OK, delete backup config
rm $tmp_config