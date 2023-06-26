#!/bin/sh

script_home=$(dirname "$(realpath "$0")")
. "$script_home/common.sh"

SUPPORT_LOG_NAME="support-log"
SUPPORT_LOG_HOME="$script_home/$SUPPORT_LOG_NAME"

rm -rf "$SUPPORT_LOG_HOME"
mkdir -p "$SUPPORT_LOG_HOME"
touch "$SUPPORT_LOG_HOME/env"

echo -e "==== OS VERSION ====" | tee "$SUPPORT_LOG_HOME/env" > /dev/null
cat /etc/os-release | tee -a "$SUPPORT_LOG_HOME/env" > /dev/null

echo -e "\n==== Docker VERSION ====" | tee -a "$SUPPORT_LOG_HOME/env" > /dev/null
docker version | tee -a "$SUPPORT_LOG_HOME/env" > /dev/null

echo -e "\n==== Docker Compose VERSION ====" | tee -a "$SUPPORT_LOG_HOME/env" > /dev/null
docker-compose version | tee -a "$SUPPORT_LOG_HOME/env" > /dev/null

echo -e "\n==== Mem INFO ====" | tee -a "$SUPPORT_LOG_HOME/env" > /dev/null
cat /proc/meminfo | tee -a "$SUPPORT_LOG_HOME/env" > /dev/null

echo -e "\n==== CPU INFO ====" | tee -a "$SUPPORT_LOG_HOME/env" > /dev/null
cat /proc/cpuinfo | tee -a "$SUPPORT_LOG_HOME/env" > /dev/null
lscpu | tee -a "$SUPPORT_LOG_HOME/env" > /dev/null

echo -e "\n==== Disk INFO ====" | tee -a "$SUPPORT_LOG_HOME/env" > /dev/null
df -h "$script_home" | tee -a "$SUPPORT_LOG_HOME/env" > /dev/null
df -h "$(which docker)" | tee -a "$SUPPORT_LOG_HOME/env" > /dev/null

cp "$script_home/.version" "$SUPPORT_LOG_HOME/version"
cp "$script_home/config/relayer/version.log" "$SUPPORT_LOG_HOME/relayer.version.log"
cp "$script_home/config/refiner/version.log" "$SUPPORT_LOG_HOME/relayer.version.log"
docker cp srpc2-relayer:/version "$SUPPORT_LOG_HOME/relayer.version"
docker cp srpc2-refiner:/version "$SUPPORT_LOG_HOME/refiner.version"

docker container inspect srpc2-relayer > "$SUPPORT_LOG_HOME/relayer.info"
docker container inspect srpc2-refiner > "$SUPPORT_LOG_HOME/refiner.info"

relayer_container_path="$(dirname `docker container inspect srpc2-relayer | grep LogPath | cut -d \" -f4`)"
refiner_container_path="$(dirname `docker container inspect srpc2-refiner | grep LogPath | cut -d \" -f4`)"

ln -sf "$relayer_container_path" "$SUPPORT_LOG_HOME/relayer"
ln -sf "$refiner_container_path" "$SUPPORT_LOG_HOME/refiner"

tar -czvhf "$SUPPORT_LOG_HOME-$(date +%s).tar.gz" -C "$script_home" "$SUPPORT_LOG_NAME"
rm -rf "$SUPPORT_LOG_HOME"