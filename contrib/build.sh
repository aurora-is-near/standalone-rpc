#!/bin/sh

RELAYERVERSION="5f314c0"


docker build --build-arg RELAYERVERSION --no-cache -f Dockerfile.database -t nearaurora/srpc-database:${RELAYERVERSION} .
docker tag nearaurora/srpc-database:${RELAYERVERSION} nearaurora/srpc-database:latest

docker build --build-arg RELAYERVERSION --no-cache -f Dockerfile.endpoint -t nearaurora/srpc-endpoint:${RELAYERVERSION} .
docker tag nearaurora/srpc-endpoint:${RELAYERVERSION} nearaurora/srpc-endpoint:latest

docker build --build-arg RELAYERVERSION --no-cache -f Dockerfile.indexer -t nearaurora/srpc-indexer:${RELAYERVERSION} .
docker build --no-cache -f Dockerfile.refiner -t nearaurora/srpc-refiner:latest .


docker push nearaurora/srpc-endpoint:latest
docker push nearaurora/srpc-endpoint:${RELAYERVERSION}

docker push nearaurora/srpc-database:latest
docker push nearaurora/srpc-database:${RELAYERVERSION}

docker push nearaurora/srpc-indexer:latest
docker push nearaurora/srpc-refiner:latest
