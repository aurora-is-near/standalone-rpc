#!/bin/sh

src_dir="contrib"

if [ ! -d "./${src_dir}" ]; then
	echo "Run ./uninstall.sh from original git repository only!"
	exit 1
fi

. ./${src_dir}/bin/common.sh

if [ -f "${INSTALL_DIR}"/stop.sh ]; then
  ./"${INSTALL_DIR}"/stop.sh
fi

docker compose -f ./"${INSTALL_DIR}"/docker-compose.yaml rm -s -f -v 2>/dev/null

if [ -d "${INSTALL_DIR}" ]; then
  rm -vrf "${INSTALL_DIR}"/config 2>/dev/null
  rm -vrf "${INSTALL_DIR}"/*.sh 2>/dev/null
  rm -vrf "${INSTALL_DIR}"/*.yaml 2>/dev/null
  rm -vrf "${INSTALL_DIR}"/.latest 2>/dev/null
  rm -vrf "${INSTALL_DIR}"/.version 2>/dev/null
  if confirmed "This will delete all relayer data, are you sure?" $@; then
    rm -vrf "${INSTALL_DIR}"/engine 2>/dev/null
    rm -vrf "${INSTALL_DIR}"/near 2>/dev/null
    rm -vrf "${INSTALL_DIR}"/data 2>/dev/null
  fi
fi
