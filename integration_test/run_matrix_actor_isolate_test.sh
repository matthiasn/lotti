#!/bin/bash
# Go to directory of script
cd "$(dirname "$0")" || exit

uuid=$(uuidgen)
TEST_USER="$(tr '[:upper:]' '[:lower:]' <<< "$uuid")"
TEST_PASSWORD="${TEST_PASSWORD:-?Secret123@}"

cd docker || exit
docker compose exec dendrite create-account -config dendrite.yaml -username "$TEST_USER" -admin -password "$TEST_PASSWORD"
cd - > /dev/null || exit

cd ..

flutter test integration_test/matrix_actor_isolate_network_test.dart \
--dart-define=TEST_USER="@$TEST_USER:localhost" \
--dart-define=TEST_PASSWORD="$TEST_PASSWORD" "$@"
