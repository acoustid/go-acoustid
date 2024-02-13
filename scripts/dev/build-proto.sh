#!/usr/bin/env bash

cd "$(dirname "$0")/../.."

for file in `ls proto/*/*.proto`; do
  protoc \
    -I proto/ \
    --go_out=proto\
    --go_opt=paths=source_relative \
    --go-grpc_out=proto \
    --go-grpc_opt=paths=source_relative \
    --grpc-gateway_out=proto \
    --grpc-gateway_opt=paths=source_relative \
    --grpc-gateway_opt generate_unbound_methods=true \
    "$file"
done
