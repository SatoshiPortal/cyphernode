
configure() {
	local current_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
	## build setup docker image
	build_docker_image ../ cyphernodeconf && clear && echo "Thinking..."

	# configure features of cyphernode
	docker run -v $current_path/../data:/data \
             --log-driver=none\
             --rm -it cyphernodeconf:latest

	#docker image rm cyphernodeconf:latest
}
