#!/bin/bash
# Go to directory of script
cd "$(dirname "$0")" || exit

cd docker || exit
docker compose exec toxiproxy /toxiproxy-cli create -l toxiproxy:18008 -u dendrite:8008 dendrite-proxy
docker compose exec toxiproxy /toxiproxy-cli toxic add -t latency -a latency=200 dendrite-proxy
docker compose exec toxiproxy /toxiproxy-cli toxic add -t bandwidth -a rate=300 dendrite-proxy
cd ..
