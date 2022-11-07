#!/bin/sh
docker build --no-cache -f Dockerfile.database -t nearaurora/srpc-database:latest .
docker build --no-cache -f Dockerfile.indexer -t nearaurora/srpc-indexer:latest .
docker build --no-cache -f Dockerfile.endpoint -t nearaurora/srpc-endpoint:latest .
docker build --no-cache -f Dockerfile.refiner -t nearaurora/srpc-refiner:latest .
docker push nearaurora/srpc-endpoint:latest
docker push nearaurora/srpc-database:latest
docker push nearaurora/srpc-indexer:latest
docker push nearaurora/srpc-refiner:latest
