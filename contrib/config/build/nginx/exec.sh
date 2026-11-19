#!/bin/sh
set -eu

if [ ! -f /config/endpoint.conf ]; then
  echo "missing /config/endpoint.conf" >&2
  exit 1
fi

cp /config/endpoint.conf /etc/nginx/conf.d/endpoint.conf
rm -f /etc/nginx/conf.d/default.conf

if [ "$#" -eq 0 ]; then
  set -- nginx -g "daemon off;"
fi

exec "$@"
