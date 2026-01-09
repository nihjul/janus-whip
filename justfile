alias b := build

# build WHIP frontend for janus
build-whip:
	go build -o whip cmd/whip/main.go

# builds OCI image using container
container:
	container build -t janus:latest .

# builds all
build: build-whip

# runs elixir script to subscribe
script-subscribe URL:
	JANUS_URL={{URL}} elixir ./scripts/subscriber.exs

# runs elixir script to publish
script-publish URL:
	JANUS_URL={{URL}} elixir ./scripts/publisher.exs
