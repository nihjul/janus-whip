alias b := build

# build WHIP frontend for janus
build-whip:
	go build -o out/whip cmd/whip/main.go

# builds OCI image using container
container:
	container build -t janus:latest .

# builds OCI image using docker
docker:
	docker build -t janus:latest .

# builds all
build: build-whip

# website to play feed from janus
player PORT:
	python3 -m http.server {{PORT}} -d ./website
# runs elixir script to subscribe
script-subscribe URL:
	JANUS_URL={{URL}} elixir ./scripts/subscriber.exs

# runs elixir script to publish
script-publish URL:
	JANUS_URL={{URL}} elixir ./scripts/publisher.exs
