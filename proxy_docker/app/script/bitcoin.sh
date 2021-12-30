#!/bin/sh

. ./trace.sh
. ./sendtobitcoinnode.sh

deriveindex() {
  trace "Entering deriveindex()..."

  local index=${1}
  trace "[deriveindex] index=${index}"

  local pub32=$DERIVATION_PUB32
  local path=$(echo -e "$DERIVATION_PATH" | sed -En "s/n/${index}/p")

  local data="{\"pub32\":\"${pub32}\",\"path\":\"${path}\"}"
  trace "[deriveindex] data=${data}"

  send_to_pycoin "${data}"
  return $?
}

derivepubpath() {
  trace "Entering derivepubpath()..."

  # {"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/25-30"}

  send_to_pycoin $1
  return $?
}

send_to_pycoin() {
  trace "Entering send_to_pycoin()..."

  local data=${1}
  local result
  local returncode

  trace "[send_to_pycoin] curl -s -H \"Content-Type: application/json\" -d \"${data}\" ${PYCOIN_CONTAINER}/derive"

  result=$(curl -s -H "Content-Type: application/json" -d "${data}" ${PYCOIN_CONTAINER}/derive)
  returncode=$?
  trace_rc ${returncode}
  trace "[send_to_pycoin] result=${result}"

  # Output response to stdout before exiting with return code
  echo "${result}"

  trace_rc ${returncode}
  return ${returncode}

}

lowercase_if_bech32() {
  trace "Entering lowercase_bech32()..."

  local address=${1}

  # Let's lowercase bech32 addresses
  local lowercased_address
  lowercased_address=$(echo ${address} | tr '[:upper:]' '[:lower:]')
  case "${lowercased_address}" in
    bc*|tb*|bcrt*)
      address="${lowercased_address}"
      trace "[lowercase_if_bech32] lowercased bech32 address=${address}";;
  esac

  echo "${address}"
}

convert_pub32() {
  trace "Entering convert_pub32()..."

  local pub32_from=${1}
  local to_type=${2}
  local payload
  local sha256sum1
  local sha256sum2
  local checksum
  local pub32_dest

  case "${pub32_from}" in
    ${to_type}*)
      trace "[convert_pub32] Already in the right format, exiting"
      echo "${pub32_from}"
      return
      ;;
  esac

  case "${to_type}" in
    tpub)
      versionbytes="043587cf"
      ;;
    upub)
      versionbytes="044a5262"
      ;;
    vpub)
      versionbytes="045f1cf6"
      ;;
    xpub)
      versionbytes="0488b21e"
      ;;
    ypub)
      versionbytes="049d7cb2"
      ;;
    zpub)
      versionbytes="04b24746"
      ;;
    *)
      return 1
      ;;
  esac

  payload=$(echo -n "${versionbytes}$(echo -n "${pub32_from}" | base58 -d | xxd -s 4 -ps -c 74 -l 74)")
  returncode=$?
  trace_rc ${returncode}
  trace "[convert_pub32] payload=${payload}"

  # sha256sum 1:
  sha256sum1=$(echo -n "${payload}" | xxd -r -ps | sha256sum -b | cut -d' ' -f1 | tr -d "\n")
  returncode=$?
  trace_rc ${returncode}
  trace "[convert_pub32] sha256sum1=${sha256sum1}"

  # sha256sum 2:
  sha256sum2=$(echo -n "${sha256sum1}" | xxd -r -ps | sha256sum -b)
  returncode=$?
  trace_rc ${returncode}
  trace "[convert_pub32] sha256sum2=${sha256sum2}"

  # checksum:
  checksum=$(echo -n "${sha256sum2}" | xxd -r -ps | xxd -l 4 -ps)
  returncode=$?
  trace_rc ${returncode}
  trace "[convert_pub32] checksum=${checksum}"

  # pub32_dest:
  pub32_dest=$(echo -n "${payload}${checksum}" | xxd -r -ps | base58)
  returncode=$?
  trace_rc ${returncode}
  trace "[convert_pub32] pub32_dest=${pub32_dest}"

  echo "${pub32_dest}"
}

bitcoind_derive_addresses() {
  trace "Entering bitcoind_derive_addresses()..."

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
  trace "[bitcoind_derive_addresses] pub32=${pub32}"

  # This is the path in the form 1/2/8 or 1/2/3-8
  path=${2}
  trace "[bitcoind_derive_addresses] path=${path}"

  # This is the pub32 converted to xpub
  if [ "${BITCOIN_NETWORK}" = "mainnet" ]; then
    xpub=$(convert_pub32 "${pub32}" "xpub")
  else
    xpub=$(convert_pub32 "${pub32}" "tpub")
  fi
  returncode=$?
  trace_rc ${returncode}
  trace "[bitcoind_derive_addresses] xpub=${xpub}"

  # t='1/2/3-8' && echo ${t%/*} && echo ${t##*/}
  # 1/2
  # 3-8
  # t='1/2/8' && echo ${t%/*} && echo ${t##*/}
  # 1/2
  # 8

  # This is the index in the form 3-8 or 8
  index=$(echo ${path##*/})
  trace "[bitcoind_derive_addresses] index=${index}"

  # This is the path without the index, like 1/2
  path_without_index=$(echo ${path%/*})
  trace "[bitcoind_derive_addresses] path_without_index=${path_without_index}"

  # This is the starting index, eg for 3-8 it is 3
  from_n=$(echo "${index}" | cut -d '-' -f1)
  trace "[bitcoind_derive_addresses] from_n=${from_n}"

  # This is the ending index, eg for 3-8 it is 8
  # For 8 it is 8
  to_n=$(echo "${index}" | cut -d '-' -f2)
  trace "[bitcoind_derive_addresses] to_n=${to_n}"

  # If starting and ending index are the same, there's no range to derive, just the index
  if [ "${from_n}" -eq "${to_n}" ]; then
    partialdescriptor="${xpub}/${path}"
  else
    range="[${from_n},${to_n}]"
    trace "[bitcoind_derive_addresses] range=${range}"
    partialdescriptor="${xpub}/${path_without_index}/*"
  fi
  trace "[bitcoind_derive_addresses] partialdescriptor=${partialdescriptor}"

  # Build the descriptor based on the given pub32 prefix
  case ${pub32} in
    xpub*|tpub*) descriptor="pkh(${partialdescriptor})"
    ;;
    ypub*|upub*) descriptor="sh(wpkh(${partialdescriptor}))"
    ;;
    zpub*|vpub*) descriptor="wpkh(${partialdescriptor})"
    ;;
  esac
  trace "[bitcoind_derive_addresses] descriptor=${descriptor}"

  # Get the descriptor with checksum
  data='{"method":"getdescriptorinfo","params":["'${descriptor}'"]}'
  trace "[bitcoind_derive_addresses] data=${data}"
  descriptor=$(send_to_watcher_node "${data}" | jq -r ".result.descriptor")
  returncode=$?
  trace_rc ${returncode}
  trace "[bitcoind_derive_addresses] descriptor=${descriptor}"

  # Derive the addresses
  if [ -z "${range}" ]; then
    data='{"method":"deriveaddresses","params":["'${descriptor}'"]}'
  else
    data='{"method":"deriveaddresses","params":{"descriptor":"'${descriptor}'","range":'${range}'}}'
  fi
  trace "[bitcoind_derive_addresses] data=${data}"
  addresses=$(send_to_watcher_node "${data}" | jq -Mc ".result")
  returncode=$?
  trace_rc ${returncode}
  trace "[bitcoind_derive_addresses] addresses=${addresses}"

  echo "${addresses}"

  return ${returncode}
}

deriveindex_bitcoind() {
  trace "Entering deriveindex_bitcoind()..."

  # index can be in the form n or n-m, ie. 12 or 12-19
  # 12 will only derive one address at index 12
  # 12-19 will derive 8 addresses at indexes 12 to 19
  local index=${1}
  trace "[deriveindex_bitcoind] index=${index}"

  local pub32=${DERIVATION_PUB32}
  trace "[deriveindex_bitcoind] pub32=${pub32}"

  local path=$(echo -e "$DERIVATION_PATH" | sed -En "s/n/${index}/p")
  trace "[deriveindex_bitcoind] path=${path}"

  bitcoind_derive_addresses "${pub32}" "${path}"

  return $?
}

derivepubpath_bitcoind() {
  trace "Entering derivepubpath_bitcoind()..."

  # {"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/25-30"}

  local pub32
  local path

  # This is the xpub/ypub/zpub/tpub/upub/vpub
  pub32=$(echo "${1}" | jq -r ".pub32")
  trace "[derivepubpath_bitcoind] pub32=${pub32}"

  # This is the path in the form 1/2 or 1/2-8
  path=$(echo "${1}" | jq -r ".path")
  trace "[derivepubpath_bitcoind] path=${path}"

  bitcoind_derive_addresses "${pub32}" "${path}"

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

# https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md
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
# kexkey@debian01:~$ bcli deriveaddresses "$(bcli getdescriptorinfo "pkh(xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL/1/*)" | jq -r ".descriptor")" "[0,4]"
# [
#   "14qCH92HCyDDBFFZdhDt1WMfrMDYnBFYMF",
#   "17igj1BanXgMbEgnLrfYhKHtGPZeBj9CfX",
#   "1HcUHrp8YyDfssqXecCnfxd6ZLdF1y2m4d",
#   "12iJX7tpCYGYwk7pUNcjMYW2kQgY1yPwNU",
#   "13AmGioGrUqYbUVgoX2QA95NdRCbAxMJnS"
# ]
# /pycoin # ku xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL -n BTC -a -s 1/0-4
# 14qCH92HCyDDBFFZdhDt1WMfrMDYnBFYMF
# 17igj1BanXgMbEgnLrfYhKHtGPZeBj9CfX
# 1HcUHrp8YyDfssqXecCnfxd6ZLdF1y2m4d
# 12iJX7tpCYGYwk7pUNcjMYW2kQgY1yPwNU
# 13AmGioGrUqYbUVgoX2QA95NdRCbAxMJnS
#
# kexkey@debian01:~$ bcli deriveaddresses "$(bcli getdescriptorinfo "sh(wpkh(xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL/1/*))" | jq -r ".descriptor")" "[0,4]"
# [
#   "35JaJ9kTdULF549HwQQX1ffgyhzo6e8oAF",
#   "3KoUwSB6e27qMusjdPKKZL5n9Z1dCe9CEb",
#   "3AjJQ9k2sFZaXUaJfounfQ69farMtsBY2b",
#   "3Coe3nNVbRs5Q4BeJbzGUUwsxMvY5aZC2H",
#   "3FBW1Yp5j45dxEnFXvjY2j8P5NqtXUbGQC"
# ]
# /proxy # convert_pub32 xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL ypub
# ypub6ZFS8LErd4QBBVwLiy55q3icFPkSNde7zAnE895MfQsATRevcQsFDpxjadiSgUazAT5PpnAqyQtc3cu6kPGC4fRB5hgpvXVoC4NYx7B2Uih
# /pycoin # ku ypub6ZFS8LErd4QBBVwLiy55q3icFPkSNde7zAnE895MfQsATRevcQsFDpxjadiSgUazAT5PpnAqyQtc3cu6kPGC4fRB5hgpvXVoC4NYx7B2Uih -n BTC -a -s 1/0-4
# 35JaJ9kTdULF549HwQQX1ffgyhzo6e8oAF
# 3KoUwSB6e27qMusjdPKKZL5n9Z1dCe9CEb
# 3AjJQ9k2sFZaXUaJfounfQ69farMtsBY2b
# 3Coe3nNVbRs5Q4BeJbzGUUwsxMvY5aZC2H
# 3FBW1Yp5j45dxEnFXvjY2j8P5NqtXUbGQC
#
# kexkey@debian01:~$ bcli deriveaddresses "$(bcli getdescriptorinfo "wpkh(xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL/1/*)" | jq -r ".descriptor")" "[0,4]"
# [
#   "bc1q9gzuy9rp0jdsgdxf95zcxgq2shhkrqv0wy2wek",
#   "bc1qfxe0s8h2rm94hjta0red37yanjrpc08jxsjzhg",
#   "bc1qkcm45vx8svaj728q64wpsrgjks75m74ytsz54h",
#   "bc1qztrum7f79x2n9c3ecss5ygxamtxk0k643jyxh7",
#   "bc1qzly0x6djdnthpn4kju00tmaglltudc284tpqgx"
# ]
# /proxy # convert_pub32 xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL zpub
# zpub6t5hRzummjwf2o8TZKri38p7RMttKFdcuHJSuXyF3RF3WXU9s52oqtcsbqg2gPEua6CCaFmQS5F9vuWfU5gCru6mx3PFWSKHTnSCLjbc4XQ
# /pycoin # ku zpub6t5hRzummjwf2o8TZKri38p7RMttKFdcuHJSuXyF3RF3WXU9s52oqtcsbqg2gPEua6CCaFmQS5F9vuWfU5gCru6mx3PFWSKHTnSCLjbc4XQ -n BTC -a -s 1/0-4
# bc1q9gzuy9rp0jdsgdxf95zcxgq2shhkrqv0wy2wek
# bc1qfxe0s8h2rm94hjta0red37yanjrpc08jxsjzhg
# bc1qkcm45vx8svaj728q64wpsrgjks75m74ytsz54h
# bc1qztrum7f79x2n9c3ecss5ygxamtxk0k643jyxh7
# bc1qzly0x6djdnthpn4kju00tmaglltudc284tpqgx
#
# testnet
#
# debian@preprod-cyphernode:~$ bcli deriveaddresses "$(bcli getdescriptorinfo "pkh(tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk/1/*)" | jq -r ".descriptor")" "[0,4]"
# [
#   "n4Ejeb9EL6dpHQXDX1HqxsWYGedbJtAZot",
#   "mou7EK24dBS48u1qUvcyCaKrmUkjGGc84M",
#   "mk7Tg1RpQDTCUMrbPS5c5rS2zW5McNT5CD",
#   "mntSbET8Us3bjjV1UNRgk4y8KzLCt8NMDV",
#   "n1UCqQqjDe8eaPuuTQjCFnn4JKFQ9E4g2v"
# ]
# /pycoin # ku tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk -n BTCY -a -s 1/0-4
# n4Ejeb9EL6dpHQXDX1HqxsWYGedbJtAZot
# mou7EK24dBS48u1qUvcyCaKrmUkjGGc84M
# mk7Tg1RpQDTCUMrbPS5c5rS2zW5McNT5CD
# mntSbET8Us3bjjV1UNRgk4y8KzLCt8NMDV
# n1UCqQqjDe8eaPuuTQjCFnn4JKFQ9E4g2v
#
# debian@preprod-cyphernode:~$ bcli deriveaddresses "$(bcli getdescriptorinfo "sh(wpkh(tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk/1/*))" | jq -r ".descriptor")" "[0,4]"
# [
#   "2N3RtGVRuJc8zUrD2zqTmgcBakaGVEvyLRx",
#   "2N1VKRFpQVRetXGcJh4DTWVWWYJHZSTLU3x",
#   "2MvXSh2YAaZkDM2qkPvwzNkizU85qSgU5wa",
#   "2MwLhxRYQejtNRh9VJ4USH9oCBXVbe3oPkj",
#   "2N3yNaASJT3uHoDV5RTyATFS48K32TDjYrp"
# ]
# /proxy # convert_pub32 tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk upub
# upub57Wa4MvRPNyAijHCMmZ1qAk3LfAB7bQpHQA3djER2gXkS2F5vrDb1ydWmXUVqUHRBpKRfQSucSr1xeWfGtS2qF9NnCHWnCLzMD3GofE1xrd
# /pycoin # ku upub57Wa4MvRPNyAijHCMmZ1qAk3LfAB7bQpHQA3djER2gXkS2F5vrDb1ydWmXUVqUHRBpKRfQSucSr1xeWfGtS2qF9NnCHWnCLzMD3GofE1xrd -n BTCY -a -s 1/0-4
# 2N3RtGVRuJc8zUrD2zqTmgcBakaGVEvyLRx
# 2N1VKRFpQVRetXGcJh4DTWVWWYJHZSTLU3x
# 2MvXSh2YAaZkDM2qkPvwzNkizU85qSgU5wa
# 2MwLhxRYQejtNRh9VJ4USH9oCBXVbe3oPkj
# 2N3yNaASJT3uHoDV5RTyATFS48K32TDjYrp
#
# debian@preprod-cyphernode:~$ bcli deriveaddresses "$(bcli getdescriptorinfo "wpkh(tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk/1/*)" | jq -r ".descriptor")" "[0,4]"
# [
#   "tb1qlyu6umpkk0jhr33j90h3ff5qpw6t25y5f6huzp",
#   "tb1qt0cemjuvrkj2hxhwm9769hdukfu4zfdfkknxxe",
#   "tb1qxfnjka657mymehg92k3ekrmqk9289h7hvvaxaj",
#   "tb1q2rvncazgrvzllm0v5qc4nrldu4u2vkyr27ujx4",
#   "tb1qmtwk0h8hht6tqvrcwwzem48x54042fxelk8x52"
# ]
# /proxy # convert_pub32 tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk vpub
# vpub5SLqN2bLY4Wea2UKC8Le3FqYWdJd4DQKCWgGR88JQgudV84KBWP9e3HenjS5qNwLbTSEQt3U57CZqw8Dzar3dUpyeXywN7AUcw6vCDFXgMy
# /pycoin # ku vpub5SLqN2bLY4Wea2UKC8Le3FqYWdJd4DQKCWgGR88JQgudV84KBWP9e3HenjS5qNwLbTSEQt3U57CZqw8Dzar3dUpyeXywN7AUcw6vCDFXgMy -n BTCY -a -s 1/0-4
# tb1qlyu6umpkk0jhr33j90h3ff5qpw6t25y5f6huzp
# tb1qt0cemjuvrkj2hxhwm9769hdukfu4zfdfkknxxe
# tb1qxfnjka657mymehg92k3ekrmqk9289h7hvvaxaj
# tb1q2rvncazgrvzllm0v5qc4nrldu4u2vkyr27ujx4
# tb1qmtwk0h8hht6tqvrcwwzem48x54042fxelk8x52
#
# regtest
#
# kexkey@AlcodaZ-2 dist % docker exec -it $(docker ps -q -f "name=cyphernode_bitcoin") bitcoin-cli deriveaddresses "$(docker exec -it $(docker ps -q -f "name=cyphernode_bitcoin") bitcoin-cli getdescriptorinfo "pkh(tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk/1/*)" | jq -r ".descriptor")" "[0,4]"
# [
#   "n4Ejeb9EL6dpHQXDX1HqxsWYGedbJtAZot",
#   "mou7EK24dBS48u1qUvcyCaKrmUkjGGc84M",
#   "mk7Tg1RpQDTCUMrbPS5c5rS2zW5McNT5CD",
#   "mntSbET8Us3bjjV1UNRgk4y8KzLCt8NMDV",
#   "n1UCqQqjDe8eaPuuTQjCFnn4JKFQ9E4g2v"
# ]
# /pycoin # ku tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk -n BTCY -a -s 1/0-4
#
# kexkey@AlcodaZ-2 dist % docker exec -it $(docker ps -q -f "name=cyphernode_bitcoin") bitcoin-cli deriveaddresses "$(docker exec -it $(docker ps -q -f "name=cyphernode_bitcoin") bitcoin-cli getdescriptorinfo "sh(wpkh(tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk/1/*))" | jq -r ".descriptor")" "[0,4]"
# [
#   "2N3RtGVRuJc8zUrD2zqTmgcBakaGVEvyLRx",
#   "2N1VKRFpQVRetXGcJh4DTWVWWYJHZSTLU3x",
#   "2MvXSh2YAaZkDM2qkPvwzNkizU85qSgU5wa",
#   "2MwLhxRYQejtNRh9VJ4USH9oCBXVbe3oPkj",
#   "2N3yNaASJT3uHoDV5RTyATFS48K32TDjYrp"
# ]
# kexkey@AlcodaZ-2 dist % docker exec -it $(docker ps -q -f "name=cyphernode_bitcoin") bitcoin-cli deriveaddresses "$(docker exec -it $(docker ps -q -f "name=cyphernode_bitcoin") bitcoin-cli getdescriptorinfo "wpkh(tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk/1/*)" | jq -r ".descriptor")" "[0,4]"
# [
#   "bcrt1qlyu6umpkk0jhr33j90h3ff5qpw6t25y5tnw34g",
#   "bcrt1qt0cemjuvrkj2hxhwm9769hdukfu4zfdf5l2t3s",
#   "bcrt1qxfnjka657mymehg92k3ekrmqk9289h7hw9yt2m",
#   "bcrt1q2rvncazgrvzllm0v5qc4nrldu4u2vkyrgh9l3u",
#   "bcrt1qmtwk0h8hht6tqvrcwwzem48x54042fxeal7trr"
# ]

##############################################################
##############################################################

# docker exec -it $(docker ps -q -f "name=cyphernode_proxy\.") curl -d '{"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/26-30"}' localhost:8888/derivepubpath
# {"addresses":[{"address":"mmaVh4SYCQhSmLWwFz7TuJ6WrQRYy8ertu"},{"address":"msriobrSwkReTfzvQr78de6RBfcbVCDxmX"},{"address":"mp377o3ifAGT5hnDBFjzmm8dFKEC9Cr4ct"},{"address":"mkxWm27kekHJC2kH1HgiT18xHrLMriZ3rc"},{"address":"mwoQwJckE6otryPNyeYwknsMCwjgyNWdjh"}]}
# 
# docker exec -it $(docker ps -q -f "name=cyphernode_proxy\.") curl -d '{"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/26-30"}' localhost:8888/derivepubpath_bitcoind
# ["mmaVh4SYCQhSmLWwFz7TuJ6WrQRYy8ertu","msriobrSwkReTfzvQr78de6RBfcbVCDxmX","mp377o3ifAGT5hnDBFjzmm8dFKEC9Cr4ct","mkxWm27kekHJC2kH1HgiT18xHrLMriZ3rc","mwoQwJckE6otryPNyeYwknsMCwjgyNWdjh"]
# 
# docker exec -it $(docker ps -q -f "name=cyphernode_proxy\.") curl -d '{"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/30"}' localhost:8888/derivepubpath 
# {"addresses":[{"address":"mwoQwJckE6otryPNyeYwknsMCwjgyNWdjh"}]}
# 
# docker exec -it $(docker ps -q -f "name=cyphernode_proxy\.") curl -d '{"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/30"}' localhost:8888/derivepubpath_bitcoind   
# ["mwoQwJckE6otryPNyeYwknsMCwjgyNWdjh"]
# 
# docker exec -it $(docker ps -q -f "name=cyphernode_proxy\.") curl localhost:8888/deriveindex/26-30         
# {"addresses":[{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},{"address":"2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6"},{"address":"2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH"},{"address":"2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"}]}
# 
# docker exec -it $(docker ps -q -f "name=cyphernode_proxy\.") curl localhost:8888/deriveindex_bitcoind/26-30
# ["2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV","2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP","2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6","2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH","2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"]
# 
# docker exec -it $(docker ps -q -f "name=cyphernode_proxy\.") curl localhost:8888/deriveindex/30   
# {"addresses":[{"address":"2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"}]}
# 
# docker exec -it $(docker ps -q -f "name=cyphernode_proxy\.") curl localhost:8888/deriveindex_bitcoind/30
# ["2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"]
# 
