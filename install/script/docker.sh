build_docker_image() {
  
  local dockerfile="Dockerfile"

  if [[ ""$3 != "" ]]; then
    dockerfile=$3
  fi

  trace "building docker image: $2:latest"
  docker build -q $1 -f $1/$dockerfile -t $2:latest > /dev/null

}
