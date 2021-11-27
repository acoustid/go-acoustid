#!/usr/bin/env bash

protoc -I proto/ proto/index/index.proto --go_out=plugins=grpc:proto
