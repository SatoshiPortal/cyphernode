#!/bin/sh

. ./trace.sh

build_docker_image() {
	
	trace "building docker image: $1 with tag $2:latest"
	docker build $1 -t $2:latest

}
