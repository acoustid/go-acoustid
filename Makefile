all: build

build:
	go build ./...
	go build -o aserver ./cmd/aserver

check:
	go test ./...

clean:
	go clean ./...
	rm -f aserver gen_pack
	rm -rf dist

.PHONY: all build check clean
