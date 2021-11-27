#!/usr/bin/env bash

set -eu

echo "$QUAY_PASSWORD" | docker login quay.io --username "$QUAY_USERNAME" --password-stdin

set -x

VERSION=$(echo "$GITHUB_REF" | cut -d/ -f3-)

# docker push quay.io/acoustid/acoustid-index:$VERSION
docker push quay.io/acoustid/acoustid-index-updater:$VERSION
docker push quay.io/acoustid/acoustid-index-proxy:$VERSION

# docker push quay.io/acoustid/acoustid-server:$VERSION
# docker push quay.io/acoustid/acoustid-server-api:$VERSION
