#!/bin/bash

### Execute this on a freshly install ubuntu luna node
# curl -fsSL get.docker.com -o get-docker.sh
# sh get-docker.sh
# sudo usermod -aG docker $USER
## logout and relogin
# git clone --branch features/install --recursive https://github.com/schulterklopfer/cyphernode.git
# sudo curl -L "https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# sudo chmod +x /usr/local/bin/docker-compose
# cd cyphernode
# ./setup.sh -ci
# docker-compose -f docker-compose.yaml up [-d]


## utils -----
trace()
{
  if [ -n "${TRACING}" ]; then
    echo -n "[$(date +%Y-%m-%dT%H:%M:%S%z)] ${1}" > /dev/stderr
  fi
}
# FROM: https://stackoverflow.com/questions/5195607/checking-bash-exit-status-of-several-commands-efficiently
# Use step(), try(), and next() to perform a series of commands and print
# [  OK  ] or [FAILED] at the end. The step as a whole fails if any individual
# command fails.
#
# Example:
#     step "Remounting / and /boot as read-write:"
#     try mount -o remount,rw /
#     try mount -o remount,rw /boot
#     next
step() {
    trace "$@"

    STEP_OK=0
    [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$
}

try() {
    # Check for `-b' argument to run command in the background.
    local BG=

    [[ $1 == -b ]] && { BG=1; shift; }
    [[ $1 == -- ]] && {       shift; }

    # Run the command.
    if [[ -z $BG ]]; then
        "$@"
    else
        "$@" &
    fi

    # Check if command failed and update $STEP_OK if so.
    local EXIT_CODE=$?

    if [[ $EXIT_CODE -ne 0 ]]; then
        STEP_OK=$EXIT_CODE
        [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$

        if [[ -n $LOG_STEPS ]]; then
            local FILE=$(readlink -m "${BASH_SOURCE[1]}")
            local LINE=${BASH_LINENO[0]}

            echo "$FILE: line $LINE: Command \`$*' failed with exit code $EXIT_CODE." >> "$LOG_STEPS"
        fi
    fi

    return $EXIT_CODE
}

echo_success() {
  echo -n "[73G[   [32mOK[0m   ]"
}

echo_failure() {
  echo -n "[73G[ [31mFAILED[0m ]"
}

next() {
    [[ -f /tmp/step.$$ ]] && { STEP_OK=$(< /tmp/step.$$); rm -f /tmp/step.$$; }
    [[ $STEP_OK -eq 0 ]]  && echo_success || echo_failure
    echo

    return $STEP_OK
}

## /utils ----



configure() {
  local current_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
  ## build setup docker image
  local recreate=""

  if [[ $1 == 1 ]]; then
    recreate="recreate"
  fi

  

  ARCH=$(uname -m)

  if [[ $ARCH =~ ^arm ]]; then
    clear && echo "Thinking. This may take a while, since I'm a Raspberry PI and my brain is so small. :D"
  else
    clear && echo "Thinking..."
  fi

  # configure features of cyphernode
  docker run -v $current_path:/data \
             --log-driver=none\
             --rm -it cyphernodeconf:latest $(id -u):$(id -g) yo --no-insight cyphernode $recreate
}

copy_file() {
  local doCopy=0
  local sourceFile=$1
  local targetFile=$2
  local createBackup=1

  if [[ ! ''$3 == '' ]]; then
    createBackup=$3
  fi

  if [[ ! -f $sourceFile ]]; then
    return 1;
  fi
  
  if [[ -f $targetFile ]]; then
    cmp --silent $sourceFile $targetFile
    if [[ $? == 1 ]]; then
      # different content
      if [[ $createBackup == 1 ]]; then
        step "Creating backup of $targetFile"
        try cp $targetFile $targetFile-$(date +"%y-%m-%d-%T")
        next
      fi
      doCopy=1
    fi
  else
    doCopy=1
  fi

  if [[ $doCopy == 1 ]]; then
    local basename=$(basename "$sourceFile")
    step "Copying $basename"
    try cp $sourceFile $targetFile
    next
  fi
}

install_docker() {

  local archpath=$(uname -m)

  # compat mode for SatoshiPortal repo
  # TODO: add more mappings?
  if [[ $archpath == 'armv7l' ]]; then
    archpath="rpi"
  fi

  local sourceDataPath=./
  local topLevel=./

  if [[ $BITCOIN_INTERNAL == true ]]; then
    if [ ! -d $BITCOIN_DATAPATH ]; then
      step "Creating $BITCOIN_DATAPATH"
      try mkdir -p $BITCOIN_DATAPATH
      next
    fi
    copy_file $sourceDataPath/bitcoin/bitcoin.conf $BITCOIN_DATAPATH/bitcoin.conf
  fi

  if [[ $FEATURE_LIGHTNING == true ]]; then
    if [[ $LIGHTNING_IMPLEMENTATION == "c-lightning" ]]; then
        local dockerfile="Dockerfile"
        if [[ $archpath == "rpi" ]]; then
          dockerfile="Dockerfile-alpine"
        fi
        if [ ! -d $LIGHTNING_DATAPATH ]; then
          step "Creating $LIGHTNING_DATAPATH"
          try mkdir -p $LIGHTNING_DATAPATH
          next
        fi
        copy_file $sourceDataPath/lightning/c-lightning/config $LIGHTNING_DATAPATH/config
    fi
  fi

  if [[ $FEATURE_OTSCLIENT == true ]]; then
    trace "opentimestamps not supported yet." && echo
  fi 
  
  # build cyphernode images
  if [ ! -d $PROXY_DATAPATH ]; then
    step "Creating $PROXY_DATAPATH"
    try mkdir -p $PROXY_DATAPATH
    next
  fi

  if [[ ! $(docker network ls | grep cyphernodenet) =~ cyphernodenet ]]; then
    step "Creating cyphernode network"
    try docker network create cyphernodenet > /dev/null 2>&1
    next
  fi

  copy_file $sourceDataPath/installer/docker/docker-compose.yaml $topLevel/docker-compose.yaml
  copy_file $sourceDataPath/installer/start.sh $topLevel/start.sh
  copy_file $sourceDataPath/installer/stop.sh $topLevel/stop.sh

  step "Making scripts executable"  
  try chmod +x start.sh stop.sh
  next

  echo "+--------------------------+"
  echo "| To start cyphernode run: |"
  echo '| ./start.sh               |'
  echo "| To stop cyphernode run:  |"
  echo '| ./stop.sh                |'
  echo "+--------------------------+"

}

install() {
  . installer/config.sh
  if [[ ''$INSTALLER_MODE == 'none' ]]; then
    echo "Skipping installation phase"
  elif [[ ''$INSTALLER_MODE == 'docker' ]]; then
    install_docker
  fi
}


CONFIGURE=0
INSTALL=0
RECREATE=0
TRACING=1

while getopts ":cirh" opt; do
  case $opt in
    r)
      RECREATE=1
      ;;
    c)
      CONFIGURE=1
      ;;
    i)
      INSTALL=1
      ;;
    h)
      echo "Use -c to configure and -i to install or -r to recreate from config.json." >&2
      exit
      ;;
    \?)
      echo "Invalid option: -$OPTARG. Use -c to configure and -i to install or -r to recreate from config.json." >&2
      ;;
  esac
done

if [[  $CONFIGURE == 0 && $INSTALL == 0 && $RECREATE == 0 ]]; then
  CONFIGURE=1
  INSTALL=1
fi

if [[ $CONFIGURE == 1 ]]; then
  trace "Starting configuration phase" && echo
  configure $RECREATE
fi

if [[ $INSTALL == 1 ]]; then
  trace "Starting installation phase" && echo
  install
fi

