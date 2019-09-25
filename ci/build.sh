#!/usr/bin/env bash

set -eux

targets="linux/amd64"

for target in $targets
do
    os="$(echo $target | cut -d '/' -f1)"
    arch="$(echo $target | cut -d '/' -f2)"
    GOOS=$os GOARCH=$arch CGO_ENABLED=0 go build -o aindex-$os-$arch ./index/cmd/aindex
done
