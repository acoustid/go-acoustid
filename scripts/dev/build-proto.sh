#!/usr/bin/env bash

proto_files=(
  "proto/index/index.proto"
  "proto/fpstore/fpstore.proto"
)

for file in "${proto_files[@]}"; do
  protoc -I proto/ "$file" --go_out=proto --go_opt=paths=source_relative --go-grpc_out=proto --go-grpc_opt=paths=source_relative
done
