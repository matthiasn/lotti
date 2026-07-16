#!/bin/bash
set -euo pipefail

# Go to directory of script
cd "$(dirname "$0")"

cd docker
docker compose up --detach --wait --wait-timeout 60
docker compose exec -T toxiproxy /toxiproxy-cli delete dendrite-proxy \
  >/dev/null 2>&1 || true
docker compose exec -T toxiproxy /toxiproxy-cli create -l toxiproxy:18008 -u dendrite:8008 dendrite-proxy
docker compose exec -T toxiproxy /toxiproxy-cli toxic add -t latency -a latency=200 dendrite-proxy
docker compose exec -T toxiproxy /toxiproxy-cli toxic add -t bandwidth -a rate=300 dendrite-proxy
cd ..
