all: build

build:
	go build ./...
	go build -o aserver ./server/cmd/aserver
	go build -o aindex ./index/cmd/aindex
	go build -o acoustid-fpstore ./fpstore/cmd/fpstore

check:
	go test ./...

clean:
	go clean ./...
	rm -f aserver gen_pack
	rm -rf dist

.PHONY: all build check clean
