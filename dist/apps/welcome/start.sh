
echo "SCRIPT_NAME: $SCRIPT_NAME"
echo "SHARED_HTPASSWD_PATH: $SHARED_HTPASSWD_PATH"
echo "APP_SCRIPT_PATH: $APP_SCRIPT_PATH"
echo "APP_START_SCRIPT_PATH: $APP_START_SCRIPT_PATH"
echo "GATEKEEPER_DATAPATH: $GATEKEEPER_DATAPATH"

export SHARED_HTPASSWD_PATH
export GATEKEEPER_DATAPATH
export APP_SCRIPT_PATH

if [ "$DOCKER_MODE" == "swarm" ]; then
  docker stack deploy -c $APP_SCRIPT_PATH/docker-compose.yaml cn_welcome
elif [ "$DOCKER_MODE" == "compose" ]; then
  docker-compose -f $APP_SCRIPT_PATH/docker-compose.yaml up -d --remove-orphans
fi
