#!/bin/bash
# Backfill integration tests for self-healing sync mechanism

SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$SCRIPT_DIR/.."
DOCKER_DIR="$SCRIPT_DIR/docker"

# Create 2 users for the backfill tests
TEST_USERS=()
for _ in {1..2}; do
  uuid=$(uuidgen)
  TEST_USERS+=("$(tr '[:upper:]' '[:lower:]' <<< "$uuid")")
done

# Create test users in Dendrite
echo "Creating test users for backfill tests..."
for user in "${TEST_USERS[@]}"; do
  docker compose -f "$DOCKER_DIR/docker-compose.yml" exec dendrite \
    create-account -config dendrite.yaml -username "$user" -admin -password "?Secret123@" 2>/dev/null || true
done

echo "Running backfill integration tests..."
echo "Test users: @${TEST_USERS[0]}:localhost / @${TEST_USERS[1]}:localhost"

cd "$PROJECT_ROOT" || exit

fvm flutter test integration_test/backfill_integration_test.dart \
  -d macos \
  --dart-define=TEST_USER1="@${TEST_USERS[0]}:localhost" \
  --dart-define=TEST_USER2="@${TEST_USERS[1]}:localhost" "$@"
