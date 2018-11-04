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
    echo -n "[$(date +%Y-%m-%dT%H:%M:%S%z)] ${1}"
  fi
}

log()
{
  echo -n "${1}"
}

logline()
{
  echo "${1}"
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
    log "$@"

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
  #echo -n "[70G[   [32mOK[0m   ]"
  echo -n
}

echo_failure() {
  echo -n "[70G[ [31mFAILED[0m ]"
}

next() {
    [[ -f /tmp/step.$$ ]] && { STEP_OK=$(< /tmp/step.$$); rm -f /tmp/step.$$; }
    [[ $STEP_OK -eq 0 ]]  && echo_success || echo_failure
    echo

    return $STEP_OK
}

cowsay() {
echo '[38;5;148m[39m
[38;5;184m [39m[38;5;184m [39m[38;5;184m [39m[38;5;184m [39m[38;5;184m [39m[38;5;184m [39m[38;5;184m [39m[38;5;184m [39m[38;5;184m [39m[38;5;178m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m_[39m[38;5;208m_[39m[38;5;208m_[39m[38;5;208m_[39m[38;5;208m_[39m[38;5;208m_[39m[38;5;208m_[39m[38;5;209m_[39m[38;5;203m_[39m[38;5;203m_[39m[38;5;203m_[39m[38;5;203m_[39m[38;5;203m_[39m[38;5;203m_[39m[38;5;203m_[39m[38;5;203m_[39m[38;5;203m_[39m[38;5;203m_[39m[38;5;203m_[39m[38;5;204m_[39m[38;5;198m_[39m[38;5;198m_[39m[38;5;198m_[39m[38;5;198m_[39m[38;5;198m_[39m[38;5;198m_[39m[38;5;198m_[39m[38;5;198m_[39m[38;5;198m_[39m[38;5;199m_[39m[38;5;199m_[39m[38;5;199m_[39m[38;5;199m_[39m[38;5;199m_[39m[38;5;199m_[39m[38;5;199m_[39m[38;5;199m_[39m[38;5;199m [39m[38;5;163m[39m
[38;5;184m [39m[38;5;184m [39m[38;5;184m [39m[38;5;184m [39m[38;5;184m [39m[38;5;184m [39m[38;5;178m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m/[39m[38;5;208m [39m[38;5;208mT[39m[38;5;208mo[39m[38;5;208m [39m[38;5;209ms[39m[38;5;203mt[39m[38;5;203ma[39m[38;5;203mr[39m[38;5;203mt[39m[38;5;203m [39m[38;5;203mc[39m[38;5;203my[39m[38;5;203mp[39m[38;5;203mh[39m[38;5;203me[39m[38;5;203mr[39m[38;5;204mn[39m[38;5;198mo[39m[38;5;198md[39m[38;5;198me[39m[38;5;198m [39m[38;5;198mr[39m[38;5;198mu[39m[38;5;198mn[39m[38;5;198m:[39m[38;5;198m [39m[38;5;199m.[39m[38;5;199m/[39m[38;5;199ms[39m[38;5;199mt[39m[38;5;199ma[39m[38;5;199mr[39m[38;5;199mt[39m[38;5;199m.[39m[38;5;199ms[39m[38;5;163mh[39m[38;5;163m [39m[38;5;164m\[39m[38;5;164m[39m
[38;5;184m [39m[38;5;184m [39m[38;5;184m [39m[38;5;178m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m\[39m[38;5;208m [39m[38;5;209mT[39m[38;5;203mo[39m[38;5;203m [39m[38;5;203ms[39m[38;5;203mt[39m[38;5;203mo[39m[38;5;203mp[39m[38;5;203m [39m[38;5;203mc[39m[38;5;203my[39m[38;5;203mp[39m[38;5;203mh[39m[38;5;204me[39m[38;5;198mr[39m[38;5;198mn[39m[38;5;198mo[39m[38;5;198md[39m[38;5;198me[39m[38;5;198m [39m[38;5;198mr[39m[38;5;198mu[39m[38;5;198mn[39m[38;5;199m:[39m[38;5;199m [39m[38;5;199m [39m[38;5;199m.[39m[38;5;199m/[39m[38;5;199ms[39m[38;5;199mt[39m[38;5;199mo[39m[38;5;199mp[39m[38;5;163m.[39m[38;5;163ms[39m[38;5;164mh[39m[38;5;164m [39m[38;5;164m [39m[38;5;164m/[39m[38;5;164m[39m
[38;5;178m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;209m [39m[38;5;203m [39m[38;5;203m-[39m[38;5;203m-[39m[38;5;203m-[39m[38;5;203m-[39m[38;5;203m-[39m[38;5;203m-[39m[38;5;203m-[39m[38;5;203m-[39m[38;5;203m-[39m[38;5;203m-[39m[38;5;204m-[39m[38;5;198m-[39m[38;5;198m-[39m[38;5;198m-[39m[38;5;198m-[39m[38;5;198m-[39m[38;5;198m-[39m[38;5;198m-[39m[38;5;198m-[39m[38;5;198m-[39m[38;5;199m-[39m[38;5;199m-[39m[38;5;199m-[39m[38;5;199m-[39m[38;5;199m-[39m[38;5;199m-[39m[38;5;199m-[39m[38;5;199m-[39m[38;5;199m-[39m[38;5;163m-[39m[38;5;163m-[39m[38;5;164m-[39m[38;5;164m-[39m[38;5;164m-[39m[38;5;164m-[39m[38;5;164m-[39m[38;5;164m-[39m[38;5;164m [39m[38;5;164m[39m
[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;209m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;204m\[39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m^[39m[38;5;198m_[39m[38;5;198m_[39m[38;5;198m^[39m[38;5;198m[39m
[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;214m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;209m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;204m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m\[39m[38;5;198m [39m[38;5;198m [39m[38;5;198m([39m[38;5;198mo[39m[38;5;198mo[39m[38;5;199m)[39m[38;5;199m\[39m[38;5;199m_[39m[38;5;199m_[39m[38;5;199m_[39m[38;5;199m_[39m[38;5;199m_[39m[38;5;199m_[39m[38;5;199m_[39m[38;5;163m[39m
[38;5;214m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;209m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;204m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;199m([39m[38;5;199m_[39m[38;5;199m_[39m[38;5;199m)[39m[38;5;199m\[39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;163m [39m[38;5;163m [39m[38;5;164m [39m[38;5;164m)[39m[38;5;164m\[39m[38;5;164m/[39m[38;5;164m\[39m[38;5;164m[39m
[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;209m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;204m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m|[39m[38;5;199m|[39m[38;5;163m-[39m[38;5;163m-[39m[38;5;164m-[39m[38;5;164m-[39m[38;5;164mw[39m[38;5;164m [39m[38;5;164m|[39m[38;5;164m[39m
[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;208m [39m[38;5;209m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;203m [39m[38;5;204m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;198m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;199m [39m[38;5;163m [39m[38;5;163m|[39m[38;5;164m|[39m[38;5;164m [39m[38;5;164m [39m[38;5;164m [39m[38;5;164m [39m[38;5;164m [39m[38;5;164m|[39m[38;5;164m|[39m[38;5;164m[39m
[38;5;208m[39m
[m[?25h[?1;5;2004l'
}

## /utils ----


modify_permissions() {
  local directories=("installer" "gatekeeper" "lightning" "bitcoin" "docker-compose.yaml $BITCOIN_DATAPATH" "$LIGHTNING_DATAPATH" "$PROXY_DATAPATH" "$GATEKEEPER_DATAPATH")
  for d in "${directories[@]}"
  do
    if [[ -e $d ]]; then
      step "   [32mmodify[0m permissions: $d"
      try chmod -R og-rwx $d
      next
    fi
  done
}

modify_owner() {
  if [[ ! $RUN_AS_USER == $USER ]]; then
    local directories=("$BITCOIN_DATAPATH" "$LIGHTNING_DATAPATH" "$PROXY_DATAPATH" "$GATEKEEPER_DATAPATH")
    local user=$(id -u $RUN_AS_USER):$(id -g $RUN_AS_USER)
    for d in "${directories[@]}"
    do
      if [[ -e $d ]]; then
        step "   [32mmodify[0m owner \"$RUN_AS_USER\": $d "
        if [[ $(id -u) == 0 ]]; then
          try chown -R $user $d
        else
          try sudo chown -R $user $d
        fi
        next
      fi
    done
  fi
}

configure() {
  local current_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
  ## build setup docker image
  local recreate=""

  if [[ $1 == 1 ]]; then
    recreate="recreate"
  fi

  

  local arch=$(uname -m)
  local pw_env=''
  local interactive=''
  local gen_options=''

  if [[ -t 1 ]]; then
    interactive=' -it'
  else
    gen_options=' --force 2'
  fi

  if [[ $CFG_PASSWORD ]]; then
    pw_env=" -e CFG_PASSWORD=$CFG_PASSWORD"
  fi


  if [[ $arch =~ ^arm ]]; then
    clear && echo "Thinking. This may take a while, since I'm a Raspberry PI and my brain is so tiny. :("
  else
    clear && echo "Thinking..."
  fi

  # configure features of cyphernode
  docker run -v $current_path:/data \
             -e DEFAULT_USER=$USER \
             --log-driver=none$pw_env \
             --rm$interactive cyphernodeconf:latest $(id -u):$(id -g) yo --no-insight cyphernode$gen_options $recreate
}

copy_file() {
  local doCopy=0
  local sourceFile=$1
  local targetFile=$2
  local sudo=''
  local createBackup=1

  if [[ $4 == 1 ]]; then
    sudo='sudo '
  fi

  if [[ ! ''$3 == '' ]]; then
    createBackup=$3
  fi

  if [[ ! -f $sourceFile ]]; then
    return 1;
  fi
  
  if [[ -f $targetFile ]]; then
    ${sudo}cmp --silent $sourceFile $targetFile
    if [[ $? == 1 ]]; then
      # different content
      if [[ $createBackup == 1 ]]; then
        step "   [32mcreate[0m backup of $targetFile "
        try ${sudo}cp $targetFile $targetFile-$(date +"%y-%m-%d-%T")
        next
      fi
      doCopy=1
    else 
      logline "[36midentical[0m $sourceFile == $targetFile"
    fi
  else
    doCopy=1
  fi

  if [[ $doCopy == 1 ]]; then
    local basename=$(basename "$sourceFile")
    step "     [32mcopy[0m $sourceFile => $targetFile "
    try ${sudo}cp $sourceFile $targetFile
    next
  fi
}

create_user() {
  #check if user exists
  if [[ ! $RUN_AS_USER == $USER ]]; then
    local OS=$(uname -s)

    if [[ $OS == 'Darwin' ]]; then
      echo "          [31mAutomatic user creation not supported on OSX.[0m"
      echo "          [31mPlease create the user \"$RUN_AS_USER\" by hand.[0m"
    else
      if [[ ! $RUN_AS_USER ]]; then
        echo "          [31mNo runtime user. Aborting[0m"
        exit 1    
      fi

      id -u $RUN_AS_USER > /dev/null 2>&1 
      if [[ $? == 1 ]]; then
        step "   [32mcreate[0m user $RUN_AS_USER "
        if [[ $(id -u) == 0 ]]; then
          try useradd $RUN_AS_USER
        else
          try sudo useradd $RUN_AS_USER
        fi
        next
      fi
    fi
  fi
}

process_bitcoinconf() {

  local bitcoinconf=$1

  # grep for prune entry and delete all whitespaces
  local pruneEntry=$(grep -e ^prune $bitcoinconf | tr -d '[:space:]')
  local txindexEntry=$(grep -e ^txindex $bitcoinconf | tr -d '[:space:]')
  local testnetEntry=$(grep -e ^testnet $bitcoinconf | tr -d '[:space:]')
  local regtestEntry=$(grep -e ^regtest $bitcoinconf | tr -d '[:space:]')

  local prune=0
  local txindex=0
  local testnet=0
  local regtest=0

  if [[ $pruneEntry =~ ^prune && ! $pruneEntry == 'prune=0' ]]; then
    prune=1
  fi

  if [[ $txindexEntry =~ ^txindex && ! $txindexEntry == 'txindex=0' ]]; then
    txindex=1
  fi

  if [[ $testnetEntry =~ ^testnet && ! $testnetEntry == 'testnet=0' ]]; then
    testnet=1
  fi

  if [[ $regtestEntry =~ ^regtest && ! $regtestEntry == 'regtest=0' ]]; then
    regtest=1
  fi
  #  prune &  txindex: 3
  # !prune &  txindex: 2
  #  prune & !txindex: 1
  # !prune & !txindex: 0
  echo $(($prune|$txindex<<1|$testnet<<2|$regtest<<3))
}


compare_bitcoinconf() {

  local new_bitcoinconf=$1
  local old_bitcoinconf=$2

  local old_config=$(process_bitcoinconf $old_bitcoinconf )
  local new_config=$(process_bitcoinconf $new_bitcoinconf )

  local old_prune=$(($old_config&1))
  local old_txindex=$((($old_config>>1)&1))
  local old_testnet=$((($old_config>>2)&1))
  local old_regtest=$((($old_config>>3)&1))
  local new_prune=$(($new_config&1))
  local new_txindex=$((($new_config>>1)&1))
  local new_testnet=$((($new_config>>2)&1))
  local new_regtest=$((($new_config>>3)&1))

  local status

  if [[ $new_prune == 1 && $old_prune == 0 ]]; then
    # warn about data loss
    # ask for user permission
    status='dataloss'
  fi

  if [[ $new_txindex == 1 && $old_txindex == 0 ]]; then
    # warn about reindexing
    status='reindex'
  fi

  if [[ ! $new_testnet == $old_testnet || ! $new_regtest == $old_regtest ]]; then
    # warn about reindexing
    status='incompatible'
  fi

  echo $status

}

install_docker() {

  local archpath=$(uname -m)

  # compat mode for SatoshiPortal repo
  # TODO: add more mappings?
  if [[ $archpath == 'armv7l' ]]; then
    archpath="rpi"
  fi

  local sourceDataPath=.

  if [ ! -d $GATEKEEPER_DATAPATH ]; then
    step "   [32mcreate[0m $GATEKEEPER_DATAPATH"
    try mkdir -p $GATEKEEPER_DATAPATH
    next
  fi

  if [ -d $GATEKEEPER_DATAPATH ]; then
    if [[ ! -d $GATEKEEPER_DATAPATH/certs ]]; then
      mkdir $GATEKEEPER_DATAPATH/certs
    fi

    if [[ ! -d $GATEKEEPER_DATAPATH/private ]]; then
      mkdir $GATEKEEPER_DATAPATH/private
    fi

    copy_file $sourceDataPath/gatekeeper/api.properties $GATEKEEPER_DATAPATH/api.properties 1 $SUDO_REQUIRED
    copy_file $sourceDataPath/gatekeeper/keys.properties $GATEKEEPER_DATAPATH/keys.properties 1 $SUDO_REQUIRED
    copy_file $sourceDataPath/gatekeeper/ip-whitelist.conf $GATEKEEPER_DATAPATH/ip-whitelist.conf 1 $SUDO_REQUIRED
    copy_file $sourceDataPath/gatekeeper/cert.pem $GATEKEEPER_DATAPATH/certs/cert.pem 1 $SUDO_REQUIRED
    copy_file $sourceDataPath/gatekeeper/key.pem $GATEKEEPER_DATAPATH/private/key.pem 1 $SUDO_REQUIRED
  fi
  
  if [ ! -d $PROXY_DATAPATH ]; then
    step "   [32mcreate[0m $PROXY_DATAPATH"
    try mkdir -p $PROXY_DATAPATH
    next
  fi

  if [[ $BITCOIN_INTERNAL == true ]]; then
    if [ ! -d $BITCOIN_DATAPATH ]; then
      step "   [32mcreate[0m $BITCOIN_DATAPATH"
      try mkdir -p $BITCOIN_DATAPATH
      next
    fi
    if [ -d $BITCOIN_DATAPATH ]; then

      local cmpStatus=$(compare_bitcoinconf $sourceDataPath/bitcoin/bitcoin.conf $BITCOIN_DATAPATH/bitcoin.conf) 

      if [[ $cmpStatus == 'dataloss' ]]; then
        if [[ $ALWAYSYES == 1 ]]; then
          copy_file $sourceDataPath/bitcoin/bitcoin.conf $BITCOIN_DATAPATH/bitcoin.conf 1 $SUDO_REQUIRED
        else
          while true; do
            echo "          [31mReally copy bitcoin.conf with pruning option?[0m"
            read -p "          [31mThis will discard some blockchain data. (yn)[0m " yn
            case $yn in
              [Yy]* ) copy_file $sourceDataPath/bitcoin/bitcoin.conf $BITCOIN_DATAPATH/bitcoin.conf 1 $SUDO_REQUIRED; break;;
              [Nn]* ) copy_file $sourceDataPath/bitcoin/bitcoin.conf $BITCOIN_DATAPATH/bitcoin.conf.cyphernode 0 $SUDO_REQUIRED
                      echo "          [31mYour cyphernode installation is most likely broken.[0m"
                      echo "          [31mPlease check bitcoin.conf.cyphernode on how to repair it manually.[0m";
                      break;;
              * ) echo "Please answer yes or no.";;
            esac
          done
        fi
      elif [[ $cmpStatus == 'incompatible' ]]; then
        copy_file $sourceDataPath/bitcoin/bitcoin.conf $BITCOIN_DATAPATH/bitcoin.conf.cyphernode 0 $SUDO_REQUIRED
        echo "          [31mBlockchain data is not compatible, due to misconfigured nets.[0m"
        echo "          [31mYour cyphernode installation is most likely broken.[0m"
        echo "          [31mPlease check bitcoin.conf.cyphernode on how to repair it manually.[0m"
      else
        if [[ $cmpStatus == 'reindex' ]]; then
          echo "  [33mWarning[0m Reindexing will take some time."
        fi
        copy_file $sourceDataPath/bitcoin/bitcoin.conf $BITCOIN_DATAPATH/bitcoin.conf 1 $SUDO_REQUIRED
      fi
    fi
  fi

  if [[ $FEATURE_LIGHTNING == true ]]; then
    if [[ $LIGHTNING_IMPLEMENTATION == "c-lightning" ]]; then
        local dockerfile="Dockerfile"
        if [[ $archpath == "rpi" ]]; then
          dockerfile="Dockerfile-alpine"
        fi
        if [ ! -d $LIGHTNING_DATAPATH ]; then
          step "   [32mcreate[0m $LIGHTNING_DATAPATH"
          try mkdir -p $LIGHTNING_DATAPATH
          next
        fi
        if [ -d $LIGHTNING_DATAPATH ]; then
          copy_file $sourceDataPath/lightning/c-lightning/config $LIGHTNING_DATAPATH/config 1 $SUDO_REQUIRED
          copy_file $sourceDataPath/lightning/c-lightning/bitcoin.conf $LIGHTNING_DATAPATH/bitcoin.conf 1 $SUDO_REQUIRED
        fi
    fi
  fi

  local net_entry=$(docker network ls | grep cyphernodenet);

  if [[ $net_entry =~ 'cyphernodenet' ]]; then
    if [[ $net_entry =~ 'local' && $DOCKER_MODE == 'swarm' ]]; then
      step " [32mrecreate[0m cyphernode network"
      try docker network rm cyphernodenet > /dev/null 2>&1
      try docker network create -d overlay cyphernodenet > /dev/null 2>&1
      next
    elif [[ $net_entry =~ 'swarm' && $DOCKER_MODE == 'compose' ]]; then
      step " [32mrecreate[0m cyphernode network"
      try docker network rm cyphernodenet > /dev/null 2>&1
      try docker network create cyphernodenet > /dev/null 2>&1
      next
    fi
  else
    if [[ $DOCKER_MODE == 'swarm' ]]; then
      step "   [32mcreate[0m cyphernode network"
      try docker network create -d overlay cyphernodenet > /dev/null 2>&1
      next
    elif [[ $DOCKER_MODE == 'compose' ]]; then
      step "   [32mcreate[0m cyphernode network"
      try docker network create cyphernodenet > /dev/null 2>&1
      next
    fi
  fi

  copy_file $sourceDataPath/installer/docker/docker-compose.yaml docker-compose.yaml
  copy_file $sourceDataPath/installer/start.sh start.sh 0
  copy_file $sourceDataPath/installer/stop.sh stop.sh 0

  if [[ ! -x start.sh ]]; then
    step "     [32mmake[0m start.sh executable"
    try chmod +x start.sh
    next
  fi

  if [[ ! -x stop.sh ]]; then
    step "     [32mmake[0m stop.sh executable"
    try chmod +x stop.sh
    next
  fi

  create_user
  modify_owner
  cowsay
}

check_directory_owner() {
  # if one directory does not have access rights for $RUN_AS_USER, we echo 1, else we echo 0
  local directories=("$BITCOIN_DATAPATH" "$LIGHTNING_DATAPATH" "$PROXY_DATAPATH" "$GATEKEEPER_DATAPATH")
  local status=0
  for d in "${directories[@]}"
  do
    if [[ -e $d ]]; then
      # is it mine and does it have rw ?
      # don't care about group rights
      if [[ ! -r $d || ! -w $d ]]; then
        status=1
        break;
      fi
      # TODO: does parent exist and do we have rw on that?
    fi
  done
  echo $status
}

check_is_sudoer() {
  echo "    [32mcheck[0m Cyphernode installer has determined that it needs sudo to continue."
  echo "          Let's verify that you have sudo rights..."
  sudo echo "     [32mYes![0m You have what it takes to run cyphernode."

  if [[ $? == 1 ]]; then
    echo "   [31mAARGH![0m Mein Leben..."
    return 1
  fi
}

check_bitcoind() {
  echo 0
}

sanity_checks() {

  echo "    [32mcheck[0m requirements."

  if [[ ''$RUN_AS_USER == '' ]]; then
    RUN_AS_USER=$USER
  fi

  local sudo=0
  local sudo_reason

  if [[ ! ''$RUN_AS_USER == ''$USER ]]; then
    sudo=1
    sudo_reason='user'
  fi
  
  if [[ $sudo == 0 ]]; then
    # we still don't need sudo. Let's check access to directories
    sudo=$(check_directory_owner)
    sudo_reason='directories'
  fi 

  if [[ $sudo == 1 ]]; then
    check_is_sudoer
    if [[ $?==1 ]]; then
      echo "          [31mTo fix this, either ask your administrator to add you to the sudo group[0m"
      if [[ $sudo_reason == 'user' ]]; then
        echo "          [31mor do not use the 'run as different user' option.[0m"
      fi
      if [[ $sudo_reason == 'directories' ]]; then
        echo "          [31mor check your data volumes if they have the right owner.[0m"
        echo "          [31mThe owner of the following folders should be '$RUN_AS_USER':[0m"
        local directories=("$BITCOIN_DATAPATH" "$LIGHTNING_DATAPATH" "$PROXY_DATAPATH" "$GATEKEEPER_DATAPATH")
          local status=0
          for d in "${directories[@]}"
          do
            if [[ -e $d ]]; then
              echo "          [31m$d[0m"
            fi
          done

      fi
      exit
    else 
      SUDO_REQUIRED=1
    fi
  else
    echo "    [32mcheck[0m everything seems to be ok."
  fi
}

install() {
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
ALWAYSYES=0
SUDO_REQUIRED=0

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
  echo "          [31mCanceling installation process.[0m"
  exit
}

while getopts ":cirhy" opt; do
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
    y)
      ALWAYSYES=1
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
  configure $RECREATE
fi

if [[ -f installer/config.sh ]]; then
  . installer/config.sh
fi

sanity_checks

if [[ $CLEANUP == 'true' && $(docker image ls | grep cyphernodeconf) =~ cyphernodeconf ]]; then
  step "    [32mclean[0m cyphernodeconf image"
  try docker image rm cyphernodeconf > /dev/null 2>&1
  next
fi

modify_permissions

if [[ $INSTALL == 1 ]]; then
  install
fi

