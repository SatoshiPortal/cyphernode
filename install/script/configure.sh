
configure() {
  local current_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
  ## build setup docker image
  local recreate=""

  if [[ $1 == 1 ]]; then
    recreate="recreate"
  fi

  build_docker_image ../ cyphernodeconf && clear && echo "Thinking..."

  # configure features of cyphernode
  docker run -v $current_path/../data:/data \
             --log-driver=none\
             --rm -it cyphernodeconf:latest $recreate
}
