#!/usr/bin/env bash

set -ex

go build ./index
go build ./index/cmd/aindex
