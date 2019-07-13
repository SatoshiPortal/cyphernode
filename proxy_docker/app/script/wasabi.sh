#@IgnoreInspection BashAddShebang

. ${DB_PATH}/config.sh

#WASABI_RPCUSER=<%= wasabi_rpcuser %>
#WASABI_RPCPASSWORD=<%= wasabi_rpcpassword %>
#WASABI_INSTANCE_COUNT=<%= wasabi_instance_count %>
#WASABI_DATAPATH=<%= wasabi_datapath %>

send_to_wasabi() {
  local index=$1 # instance index
  local method=$2 # method
  local params=$3 # json string escaped

  if [ "$#" -ne 3 ]; then
      echo "Wrong number of arguments"
      return 1
  fi

  if [ ! $index -lt "${WASABI_INSTANCE_COUNT}" ]; then
    echo "No such wasabi instance ${index}"
    return 1
  fi

  echo curl -u "$WASABI_RPCUSER:$WASABI_RPCPASSWORD" -s --data-binary "'{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"${method}\", \"params\": ${params} }'" http://wasabi_${index}:18099/
  return $?
}

random_wasabi_index() {
  echo $(( $(od -An -N2 < /dev/urandom) % $WASABI_INSTANCE_COUNT ))
}

wasabi_newaddr() {
  # wasabi rpc: getnewaddress
  # args:
  # - label (0), optional

  # queries random instance for a new bech32 address
  # returns {"jsonrpc":"2.0","result":{"address":"tb1qpgpe7mdhdpgz6894vl5a2rhvhukwjc35h99rqc","keyPath":"84'/0'/0'/0/24","label":"blah","publicKey":"024eaa964530e5a72059951cdab8d22c5df7543536b011a8bab85bc1f6089654d9","p2wpkh":"00140a039f6db768502d1cb567e9d50eecbf2ce96234"},"id":"12"}
  local label=$1

  if [ ! ${label} ]; then
    label="unknown"
  fi

  send_to_wasabi $(random_wasabi_index) getnewaddress '{ "label": "'${label}'" }'
  return $?
}

wasabi_get_balance() {

  # wasabi rpc: listunspentcoins

  # args:
  # - id: integer, optional
  # - private: boolean, optional, default=false
  # returns the total balance of either
  # - all wasabi instances
  # - a single instance, when provide with an id
  # takes a 'private' flag. if 'private' flag is set
  # the balance will only return the unspent outputs
  # which have an anon set of at least what is configured.
  # if id is defined, it will return the balance of
  # the wasabi instance with id <id>, else it will
  # return the balance of all instances
}

wasabi_spend() {

  # wasabi rpc: spend

  # args:
  # - id: integer, required
  # - private: boolean, optional, default=false
  # - address: string, required
  # - amount: number, required
}

wasabi_get_transactions() {

  # No rpc call. Needs to be implemented

  # args:
  # - id: integer, optional
  # return all transactions of either one wasabi instance
  # or all instances, depending on the id parameter
}