#!/usr/bin/env bash

set -eux

targets="linux/amd64"

rm -rf dist
mkdir dist

for target in $targets
do
    os="$(echo $target | cut -d '/' -f1)"
    arch="$(echo $target | cut -d '/' -f2)"
    GOOS=$os GOARCH=$arch CGO_ENABLED=0 go build -o dist/aserver-$os-$arch ./cmd/aserver
done
