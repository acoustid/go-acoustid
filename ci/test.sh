#!/usr/bin/env bash

set -eux

go test -v -covermode=count -coverprofile=coverage.out ./...
