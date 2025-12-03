#!/bin/bash
# Go to directory of script
cd "$(dirname "$0")" || exit

# Create 4 user pairs (one for each test to avoid device accumulation)
uuid1=$(uuidgen)
uuid2=$(uuidgen)
uuid3=$(uuidgen)
uuid4=$(uuidgen)
uuid5=$(uuidgen)
uuid6=$(uuidgen)
uuid7=$(uuidgen)
uuid8=$(uuidgen)

TEST_USER1="$(tr '[:upper:]' '[:lower:]' <<< "$uuid1")"
TEST_USER2="$(tr '[:upper:]' '[:lower:]' <<< "$uuid2")"
TEST_USER3="$(tr '[:upper:]' '[:lower:]' <<< "$uuid3")"
TEST_USER4="$(tr '[:upper:]' '[:lower:]' <<< "$uuid4")"
TEST_USER5="$(tr '[:upper:]' '[:lower:]' <<< "$uuid5")"
TEST_USER6="$(tr '[:upper:]' '[:lower:]' <<< "$uuid6")"
TEST_USER7="$(tr '[:upper:]' '[:lower:]' <<< "$uuid7")"
TEST_USER8="$(tr '[:upper:]' '[:lower:]' <<< "$uuid8")"

cd docker || exit

# Create test users
echo "Creating test users..."
docker compose exec dendrite create-account -config dendrite.yaml -username "$TEST_USER1" -admin -password "?Secret123@" 2>/dev/null || true
docker compose exec dendrite create-account -config dendrite.yaml -username "$TEST_USER2" -admin -password "?Secret123@" 2>/dev/null || true
docker compose exec dendrite create-account -config dendrite.yaml -username "$TEST_USER3" -admin -password "?Secret123@" 2>/dev/null || true
docker compose exec dendrite create-account -config dendrite.yaml -username "$TEST_USER4" -admin -password "?Secret123@" 2>/dev/null || true
docker compose exec dendrite create-account -config dendrite.yaml -username "$TEST_USER5" -admin -password "?Secret123@" 2>/dev/null || true
docker compose exec dendrite create-account -config dendrite.yaml -username "$TEST_USER6" -admin -password "?Secret123@" 2>/dev/null || true
docker compose exec dendrite create-account -config dendrite.yaml -username "$TEST_USER7" -admin -password "?Secret123@" 2>/dev/null || true
docker compose exec dendrite create-account -config dendrite.yaml -username "$TEST_USER8" -admin -password "?Secret123@" 2>/dev/null || true

cd - > /dev/null || exit
cd ..

echo "Running resilience tests..."
echo "Test 1 users: @$TEST_USER1:localhost / @$TEST_USER2:localhost"
echo "Test 2 users: @$TEST_USER3:localhost / @$TEST_USER4:localhost"
echo "Test 3 users: @$TEST_USER5:localhost / @$TEST_USER6:localhost"
echo "Test 4 users: @$TEST_USER7:localhost / @$TEST_USER8:localhost"

fvm flutter test integration_test/sync_resilience_test.dart \
-d macos \
--dart-define=TEST_USER1="@$TEST_USER1:localhost" \
--dart-define=TEST_USER2="@$TEST_USER2:localhost" \
--dart-define=TEST_USER3="@$TEST_USER3:localhost" \
--dart-define=TEST_USER4="@$TEST_USER4:localhost" \
--dart-define=TEST_USER5="@$TEST_USER5:localhost" \
--dart-define=TEST_USER6="@$TEST_USER6:localhost" \
--dart-define=TEST_USER7="@$TEST_USER7:localhost" \
--dart-define=TEST_USER8="@$TEST_USER8:localhost" \
--dart-define=SLOW_NETWORK="false" "$@"
