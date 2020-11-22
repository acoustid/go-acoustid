#!/usr/bin/env bash

set -eux

VERSION=$(echo "$GITHUB_REF" | cut -d/ -f3-)

chmod +x dist/*

docker build . -f Dockerfile.index -t quay.io/acoustid/acoustid-index:$VERSION
docker build . -f Dockerfile.index-updater --build-arg VERSION=$VERSION -t quay.io/acoustid/acoustid-index-updater:$VERSION
docker build . -f Dockerfile.index-proxy --build-arg VERSION=$VERSION -t quay.io/acoustid/acoustid-index-proxy:$VERSION
