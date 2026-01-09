alias b := build

build-whip:
	go build -o whip cmd/whip/main.go

build: build-whip
