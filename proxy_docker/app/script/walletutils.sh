. ./trace.sh
. ./sendtobitcoinnode.sh

create_wallet() {
  # defaults to blank wallet to be used for importing
  # keys for watch only mode
  trace "[Entering create_wallet()]"

  local walletname=${1}
  local disableprivatekeys=${2:-true}
  local blank=${3:-true}

  if [ ! "$disableprivatekeys" = "false" ]; then
      disableprivatekeys="true"
  fi

  if [ ! "$blank" = "false" ]; then
      blank="true"
  fi

  local rpcstring="{\"method\":\"createwallet\",\"params\":[\"${walletname}\",${disableprivatekeys},${blank}]}"
  trace "[create_wallet] rpcstring=${rpcstring}"

  local result
  result=$(send_to_watcher_node ${rpcstring})
  local returncode=$?

  echo "${result}"

  return ${returncode}
}

fingerprint_from_pub32() {
  local pub32=$1
  echo -n "$pub32" | md5 | cut -c1-8
  return $?
}
