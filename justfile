alias b := build

default:
	just --list

# build WHIP frontend for janus
build-whip:
	echo Building...
	go build -o whip cmd/whip/main.go
	echo Build complete

# builds OCI image using container
build-container:
	container build -t janus:latest .

# builds OCI image using docker
build-docker:
	docker build -t janus:latest .

# builds all
build: build-whip

# run using container
run-container:
	container run janus:latest

# run using docker
run-docker:
	docker run -p 8088:8088 -p 20000-20020:20000-20020/udp janus:latest

# run WHIP frontend
run URL:
	JANUS_URL={{URL}} ./whip

# builds and runs janus server using container
container: build-container run-container

# builds and runs janus server using docker
docker: build-docker run-docker

# website to play feed from janus
player PORT:
	python3 -m http.server {{PORT}} -d ./website
# runs elixir script to subscribe
script-subscribe URL:
	JANUS_URL={{URL}} elixir ./scripts/subscriber.exs

# runs elixir script to publish
script-publish URL:
	JANUS_URL={{URL}} elixir ./scripts/publisher.exs
