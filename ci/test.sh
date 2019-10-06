#!/usr/bin/env bash

set -eux

./dev/wait-for-it.sh $ACOUSTID_TEST_REDIS_HOST:$ACOUSTID_TEST_REDIS_PORT
./dev/wait-for-it.sh $ACOUSTID_TEST_POSTGRESQL_HOST:$ACOUSTID_TEST_POSTGRESQL_PORT

go test -v -covermode=count -coverprofile=coverage.out ./...
