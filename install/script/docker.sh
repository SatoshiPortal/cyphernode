build_docker_image() {
  
  trace "building docker image: $2:latest"
  docker build -q $1 -t $2:latest > /dev/null

}
