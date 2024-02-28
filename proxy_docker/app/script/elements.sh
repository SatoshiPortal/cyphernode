#!/bin/sh

. ./trace.sh
. ./sendtoelementsnode.sh
. ./bitcoin.sh # uses send_to_pycoin, convert_pub32

elements_derive_addresses() {
  trace "Entering elements_derive_addresses()..."

  local pub32
  local path
  local xpub
  local index
  local path_without_index
  local from_n
  local to_n
  local range
  local descfunc
  local partialdescriptor
  local descriptor
  local data
  local response
  local returncode

  # This is the xpub/ypub/zpub/tpub/upub/vpub
  pub32=${1}
  trace "[elements_derive_addresses] pub32=${pub32}"

  # This is the path in the form 1/2/8 or 1/2/3-8
  path=${2}
  trace "[elements_derive_addresses] path=${path}"

  # This is the pub32 converted to xpub
  if [ "${ELEMENTS_NETWORK}" = "mainnet" ]; then
    xpub=$(convert_pub32 "${pub32}" "xpub")
  else
    xpub=$(convert_pub32 "${pub32}" "tpub")
  fi
  returncode=$?
  trace_rc ${returncode}
  trace "[elements_derive_addresses] xpub=${xpub}"

  # t='1/2/3-8' && echo ${t%/*} && echo ${t##*/}
  # 1/2
  # 3-8
  # t='1/2/8' && echo ${t%/*} && echo ${t##*/}
  # 1/2
  # 8

  # This is the index in the form 3-8 or 8
  index=$(echo ${path##*/})
  trace "[elements_derive_addresses] index=${index}"

  # This is the path without the index, like 1/2
  path_without_index=$(echo ${path%/*})
  trace "[elements_derive_addresses] path_without_index=${path_without_index}"

  # This is the starting index, eg for 3-8 it is 3
  from_n=$(echo "${index}" | cut -d '-' -f1)
  trace "[elements_derive_addresses] from_n=${from_n}"

  # This is the ending index, eg for 3-8 it is 8
  # For 8 it is 8
  to_n=$(echo "${index}" | cut -d '-' -f2)
  trace "[elements_derive_addresses] to_n=${to_n}"

  # If starting and ending index are the same, there's no range to derive, just the index
  if [ "${from_n}" -eq "${to_n}" ]; then
    partialdescriptor="${xpub}/${path}"
  else
    range="[${from_n},${to_n}]"
    trace "[elements_derive_addresses] range=${range}"
    partialdescriptor="${xpub}/${path_without_index}/*"
  fi
  trace "[elements_derive_addresses] partialdescriptor=${partialdescriptor}"

  # Build the descriptor based on the given pub32 prefix
  case ${pub32} in
    xpub*|tpub*) descriptor="pkh(${partialdescriptor})"
    ;;
    ypub*|upub*) descriptor="sh(wpkh(${partialdescriptor}))"
    ;;
    zpub*|vpub*) descriptor="wpkh(${partialdescriptor})"
    ;;
  esac
  trace "[elements_derive_addresses] descriptor=${descriptor}"

  # Get the descriptor with checksum
  data='{"method":"getdescriptorinfo","params":["'${descriptor}'"]}'
  trace "[elements_derive_addresses] data=${data}"
  descriptor=$(send_to_elements_watcher_node "${data}" | jq -r ".result.descriptor")
  returncode=$?
  trace_rc ${returncode}
  trace "[elements_derive_addresses] descriptor=${descriptor}"

  # Derive the addresses
  if [ -z "${range}" ]; then
    data='{"method":"deriveaddresses","params":["'${descriptor}'"]}'
  else
    data='{"method":"deriveaddresses","params":{"descriptor":"'${descriptor}'","range":'${range}'}}'
  fi
  trace "[elements_derive_addresses] data=${data}"
  addresses=$(send_to_elements_watcher_node "${data}" | jq -Mc ".result")
  returncode=$?
  trace_rc ${returncode}
  trace "[elements_derive_addresses] addresses=${addresses}"

  echo "${addresses}"

  return ${returncode}
}

elements_deriveindex() {
  trace "Entering elements_deriveindex()..."

  # index can be in the form n or n-m, ie. 12 or 12-19
  # 12 will only derive one address at index 12
  # 12-19 will derive 8 addresses at indexes 12 to 19
  local index=${1}
  trace "[elements_deriveindex] index=${index}"

  local pub32=${ELEMENTS_DERIVATION_PUB32}
  trace "[elements_deriveindex] pub32=${pub32}"

  local path=$(echo "$ELEMENTS_DERIVATION_PATH" | sed -En "s/n/${index}/p")
  trace "[elements_deriveindex] path=${path}"

  elements_derive_addresses "${pub32}" "${path}"

  return $?
}

elements_derivepubpath() {
  trace "Entering elements_derivepubpath()..."

  # {"pub32":"tpubDCYNhuT4XzfTJ4GQ5hjfy4U1N1yKtheYpjNwYVGHZiES1vxDKAg1fXS9nFfoHNZ49G7iVU8LHFpoj4UehAdqQavLmhFmWaEr1ARRqLVPiRd","path":"0/25-30"}

  local pub32
  local path

  # This is the xpub/ypub/zpub/tpub/upub/vpub
  pub32=$(echo "${1}" | jq -r ".pub32")
  trace "[elements_derivepubpath] pub32=${pub32}"

  # This is the path in the form 1/2 or 1/2-8
  path=$(echo "${1}" | jq -r ".path")
  trace "[elements_derivepubpath] path=${path}"

  elements_derive_addresses "${pub32}" "${path}"

  return $?
}

# xpub = P2PKH / P2SH = 1addr or 3addr = pkh()
# ypub = Segwit P2WPKH in P2SH = 3addr = sh(wpkh())
# Ypub = Segwit Multisig P2WSH in P2SH = 3addr
# zpub = Segwit native P2WPKH = bc1addr = wpkh()
# Zpub = Segwit native Multisig P2WSH = bc1addr

# tpub = P2PKH / P2SH = nmaddr or 2addr = pkh()
# upub = Segwit P2WPKH in P2SH = 2addr = sh(wpkh())
# Upub = Segwit Multisig P2WSH in P2SH = 2addr
# vpub = Segwit native P2WPKH = tb1addr = wpkh()
# Vpub = Segwit native Multisig P2WSH = tb1addr

# https://github.com/ElementsProject/elements/blob/master/doc/descriptors.md
# Output descriptors currently support:
#
# Pay-to-pubkey scripts (P2PK), through the pk function.
# Pay-to-pubkey-hash scripts (P2PKH), through the pkh function.
# Pay-to-witness-pubkey-hash scripts (P2WPKH), through the wpkh function.
# Pay-to-script-hash scripts (P2SH), through the sh function.
# Pay-to-witness-script-hash scripts (P2WSH), through the wsh function.
# Pay-to-taproot outputs (P2TR), through the tr function.
# Multisig scripts, through the multi function.
# Multisig scripts where the public keys are sorted lexicographically, through the sortedmulti function.
# Any type of supported address through the addr function.
# Raw hex scripts through the raw function.
# Public keys (compressed and uncompressed) in hex notation, or BIP32 extended pubkeys with derivation paths.

# mainnet
#
#
#
# testnet
#
# :~$ elements-cli deriveaddresses "$(elements-cli getdescriptorinfo "pkh(tpubDCYNhuT4XzfTJ4GQ5hjfy4U1N1yKtheYpjNwYVGHZiES1vxDKAg1fXS9nFfoHNZ49G7iVU8LHFpoj4UehAdqQavLmhFmWaEr1ARRqLVPiRd/1/*)" | jq -r ".descriptor")" "[0,4]"
# [
#   "FhZbF6rZnvMcz3iWmLzHq6trLJDPAwi5R9",
#   "FXLQF9zAn6Pyvcz15RZk4GFBuFPyrMeKXS",
#   "FsKyYrft7noXxn2CoKDG5DJonNd2AtYK8V",
#   "FjHuqSxgvtLyZTNjBemsTDgKYt8aX4jqic",
#   "FsLzy9KUrqZdNEaTHg2k5K2UVriRLQxyEk"
# ]
#
# :~$ elements-cli deriveaddresses "$(elements-cli getdescriptorinfo "sh(wpkh(tpubDCYNhuT4XzfTJ4GQ5hjfy4U1N1yKtheYpjNwYVGHZiES1vxDKAg1fXS9nFfoHNZ49G7iVU8LHFpoj4UehAdqQavLmhFmWaEr1ARRqLVPiRd/1/*))" | jq -r ".descriptor")" "[0,4]"
# [
#   "92pxL4wXUujkS3xrN2t63rQM4UWMTQqosJ",
#   "8kkZKLJ8NmgVqELHDPEXji4jF23Y59KgyW",
#   "925hiTV4moe5c7NyqToTxZnZhbJqf3xZKZ",
#   "8xkhmvtioZPEa7ZDV2UscmjszuPmxGbqu4",
#   "8nW9wdcHooYCbPhBbLdEcnpn5Ma2EXWBnY"
# ]
#
# :~$ elements-cli deriveaddresses "$(elements-cli getdescriptorinfo "wpkh(tpubDCYNhuT4XzfTJ4GQ5hjfy4U1N1yKtheYpjNwYVGHZiES1vxDKAg1fXS9nFfoHNZ49G7iVU8LHFpoj4UehAdqQavLmhFmWaEr1ARRqLVPiRd/1/*)" | jq -r ".descriptor")" "[0,4]"
# [
#   "tex1qsl63qv4p5f0t05h5qxazmwthwz2v37lmcnq6p6",
#   "tex1qzlznweq450v50k7t480mjclcrxnfcpaz4t7z4d",
#   "tex1q7vf3utzwyhy0xx5vkh4az2pyszx46j7hyv8kcx",
#   "tex1qnthzmmkgxf220r22267z5ltv292ejqftmjr4dx",
#   "tex1q7dzt04mc8c2wf7nwtwwpgz0t6dqg5sud903n35"
# ]
#
# regtest
#
#
#

##############################################################
##############################################################

# docker exec -it $(docker ps -q -f "name=cyphernode_proxy\.") curl -d '{"pub32":"tpubDCYNhuT4XzfTJ4GQ5hjfy4U1N1yKtheYpjNwYVGHZiES1vxDKAg1fXS9nFfoHNZ49G7iVU8LHFpoj4UehAdqQavLmhFmWaEr1ARRqLVPiRd","path":"0/26-30"}' localhost:8888/elements_derivepubpath
###### {"addresses":[{"address":"mmaVh4SYCQhSmLWwFz7TuJ6WrQRYy8ertu"},{"address":"msriobrSwkReTfzvQr78de6RBfcbVCDxmX"},{"address":"mp377o3ifAGT5hnDBFjzmm8dFKEC9Cr4ct"},{"address":"mkxWm27kekHJC2kH1HgiT18xHrLMriZ3rc"},{"address":"mwoQwJckE6otryPNyeYwknsMCwjgyNWdjh"}]}
#
# docker exec -it $(docker ps -q -f "name=cyphernode_proxy\.") curl -d '{"pub32":"tpubDCYNhuT4XzfTJ4GQ5hjfy4U1N1yKtheYpjNwYVGHZiES1vxDKAg1fXS9nFfoHNZ49G7iVU8LHFpoj4UehAdqQavLmhFmWaEr1ARRqLVPiRd","path":"0/30"}' localhost:8888/elements_derivepubpath
###### {"addresses":[{"address":"mwoQwJckE6otryPNyeYwknsMCwjgyNWdjh"}]}
#
# docker exec -it $(docker ps -q -f "name=cyphernode_proxy\.") curl localhost:8888/elements_deriveindex/26-30
###### {"addresses":[{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},{"address":"2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6"},{"address":"2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH"},{"address":"2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"}]}
#
#
# docker exec -it $(docker ps -q -f "name=cyphernode_proxy\.") curl localhost:8888/elements_deriveindex/30
###### {"addresses":[{"address":"2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"}]}
#
#
