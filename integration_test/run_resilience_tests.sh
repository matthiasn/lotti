#!/bin/bash
# Resilience tests for Matrix sync under adverse network conditions

SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$SCRIPT_DIR/.."
DOCKER_DIR="$SCRIPT_DIR/docker"

# Create 4 user pairs (one for each test to avoid device accumulation)
TEST_USERS=()
for i in {1..8}; do
  uuid=$(uuidgen)
  TEST_USERS+=("$(tr '[:upper:]' '[:lower:]' <<< "$uuid")")
done

# Create test users in Dendrite
echo "Creating test users..."
for user in "${TEST_USERS[@]}"; do
  docker compose -f "$DOCKER_DIR/docker-compose.yml" exec dendrite \
    create-account -config dendrite.yaml -username "$user" -admin -password "?Secret123@" 2>/dev/null || true
done

echo "Running resilience tests..."
echo "Test 1 users: @${TEST_USERS[0]}:localhost / @${TEST_USERS[1]}:localhost"
echo "Test 2 users: @${TEST_USERS[2]}:localhost / @${TEST_USERS[3]}:localhost"
echo "Test 3 users: @${TEST_USERS[4]}:localhost / @${TEST_USERS[5]}:localhost"
echo "Test 4 users: @${TEST_USERS[6]}:localhost / @${TEST_USERS[7]}:localhost"

cd "$PROJECT_ROOT" || exit

fvm flutter test integration_test/sync_resilience_test.dart \
  -d macos \
  --dart-define=TEST_USER1="@${TEST_USERS[0]}:localhost" \
  --dart-define=TEST_USER2="@${TEST_USERS[1]}:localhost" \
  --dart-define=TEST_USER3="@${TEST_USERS[2]}:localhost" \
  --dart-define=TEST_USER4="@${TEST_USERS[3]}:localhost" \
  --dart-define=TEST_USER5="@${TEST_USERS[4]}:localhost" \
  --dart-define=TEST_USER6="@${TEST_USERS[5]}:localhost" \
  --dart-define=TEST_USER7="@${TEST_USERS[6]}:localhost" \
  --dart-define=TEST_USER8="@${TEST_USERS[7]}:localhost" \
  --dart-define=SLOW_NETWORK="false" "$@"
