#!/bin/bash

# Create user name
uuid=$(uuidgen)
TEST_USER=a="$(tr '[:upper:]' '[:lower:]' <<< "$uuid")"

# Go to dendrite docker directory that contains config and keys
cd ../dendrite/build/docker/config || exit

# Create user using the create-account binary in dendrite build
../../../bin/create-account -config dendrite.yaml -username "$TEST_USER" -password "?Secret123@!"
cd - > /dev/null || exit

fvm flutter test integration_test/matrix_service_test.dart --dart-define=TEST_USER="$TEST_USER"
