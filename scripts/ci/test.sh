#!/usr/bin/env bash

set -eux

./scripts/dev/wait-for-it.sh $ACOUSTID_TEST_REDIS_HOST:$ACOUSTID_TEST_REDIS_PORT
./scripts/dev/wait-for-it.sh $ACOUSTID_TEST_POSTGRESQL_HOST:$ACOUSTID_TEST_POSTGRESQL_PORT

go test -v -covermode=count -coverprofile=coverage.out ./...
