#!/bin/bash

# Create user name
uuid1=$(uuidgen)
uuid2=$(uuidgen)
TEST_USER1="$(tr '[:upper:]' '[:lower:]' <<< "$uuid1")"
TEST_USER2="$(tr '[:upper:]' '[:lower:]' <<< "$uuid2")"

# Go to dendrite docker directory that contains config and keys
cd ../dendrite/build/docker/config || exit

# Create user using the create-account binary in dendrite build
../../../bin/create-account -config dendrite.yaml -username "$TEST_USER1" -admin -password "?Secret123@!"
../../../bin/create-account -config dendrite.yaml -username "$TEST_USER2" -admin -password "?Secret123@!"
cd - > /dev/null || exit

fvm flutter test integration_test/matrix_service_test.dart \
--dart-define=TEST_USER1="@$TEST_USER1:localhost" \
--dart-define=TEST_USER2="@$TEST_USER2:localhost" \
--dart-define=SLOW_NETWORK="$SLOW_NETWORK"

