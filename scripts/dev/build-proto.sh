#!/usr/bin/env bash

cd "$(dirname "$0")/../.."

for file in `ls proto/*/*.proto`; do
  protoc -I proto/ "$file" --go_out=proto --go_opt=paths=source_relative --go-grpc_out=proto --go-grpc_opt=paths=source_relative
done
