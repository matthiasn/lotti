#!/bin/sh
# Initialize TigerBeetle database if it doesn't exist

DATA_FILE="/data/cluster_0.tigerbeetle"

if [ ! -f "$DATA_FILE" ]; then
    echo "Initializing TigerBeetle database..."
    /tigerbeetle format --cluster=0 --replica=0 --replica-count=1 "$DATA_FILE"
    echo "Database initialized"
fi

echo "Starting TigerBeetle..."
exec /tigerbeetle start --addresses=0.0.0.0:3000 --cache-grid=128MiB "$DATA_FILE"
