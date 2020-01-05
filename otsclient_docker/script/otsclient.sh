#!/bin/sh

# There an OTS server on testnet: ots.test4mind.com

. ./trace.sh

stamp() {
  trace "Entering stamp()..."

  local hash=${1}
  trace "[stamp] hash=${hash}"

  local result
  local returncode
  local data
  local proxychains=""

  if [ -n "${TOR_HOST}" ]; then
    proxychains="PROXYCHAINS_ONE_PROXY='socks5 `getent hosts ${TOR_HOST} | awk '{ print $1 }'` ${TOR_PORT}' proxychains4"
  fi

  if [ "${TESTNET}" -eq "1" ]; then
    trace "[stamp] ${proxychains} ots-cli.js stamp -c \"https://ots.testnet.kexkey.com\" -d ${hash}"
    result=$(cd /otsfiles && sh -c "${proxychains} ots-cli.js stamp -c 'https://ots.testnet.kexkey.com' -d ${hash} 2>&1")
    returncode=$?
  else
    trace "[stamp] ${proxychains} ots-cli.js stamp -d ${hash}"
    result=$(cd /otsfiles && sh -c "${proxychains} ots-cli.js stamp -d ${hash} 2>&1")
    returncode=$?
  fi
  trace_rc ${returncode}
  trace "[stamp] result=${result}"

  # The timestamp proof '1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7.ots' has been created!

  data="{\"method\":\"stamp\",\"hash\":\"${hash}\",\"result\":\""

  trace "[stamp] grepping..."
  echo "${result}" | grep "has been created!" > /dev/null
  returncode=$?
  trace_rc ${returncode}

  if [ "${returncode}" -eq "0" ]; then
    # String found
    data="${data}success\"}"
  else
    # String not found
    data="${data}error\",\"error\":\"${result}\"}"
  fi

  trace "[stamp] data=${data}"

  echo "${data}"

  return ${returncode}
}

upgrade() {
  trace "Entering upgrade()..."

  local hash=${1}
  trace "[upgrade] hash=${hash}"

  local result
  local returncode
  local proxychains=""

  if [ -n "${TOR_HOST}" ]; then
    proxychains="PROXYCHAINS_ONE_PROXY='socks5 `getent hosts ${TOR_HOST} | awk '{ print $1 }'` ${TOR_PORT}' proxychains4"
  fi

  if [ "${TESTNET}" -eq "1" ]; then
    trace "[upgrade] ${proxychains} ots-cli.js -l \"https://testnet.calendar.kexkey.com/\" --no-default-whitelist upgrade -c \"https://testnet.calendar.kexkey.com/\" ${hash}.ots"
    result=$(cd /otsfiles && sh -c "${proxychains} ots-cli.js -l 'https://testnet.calendar.kexkey.com/' --no-default-whitelist upgrade -c 'https://testnet.calendar.kexkey.com/' ${hash}.ots 2>&1")
    returncode=$?
  else
    trace "[upgrade] ${proxychains} ots-cli.js upgrade ${hash}.ots"
    result=$(cd /otsfiles && sh -c "${proxychains} ots-cli.js upgrade ${hash}.ots 2>&1")
    returncode=$?
  fi
  trace_rc ${returncode}
  trace "[upgrade] result=${result}"

  # Success! Timestamp complete
  # Failed! Timestamp not complete

  data="{\"method\":\"upgrade\",\"hash\":\"${hash}\",\"result\":\""

  trace "[upgrade] grepping..."
  echo "${result}" | grep "Success!" > /dev/null
  returncode=$?
  trace_rc ${returncode}

  if [ "${returncode}" -eq "0" ]; then
    data="${data}success\"}"
  else
    data="${data}error\",\"error\":\"${result}\"}"
  fi

  trace "[upgrade] data=${data}"

  echo "${data}"

  return ${returncode}
}

verify() {
  trace "Entering verify()..."

  local request=${1}
  local hash=$(echo "${request}" | jq ".hash" | tr -d '"')
  trace "[verify] hash=${hash}"
  local base64otsfile=$(echo "${request}" | jq ".base64otsfile" | tr -d '"')
  trace "[verify] base64otsfile=${base64otsfile}"

  local result
  local returncode
  local message
  local data
  local proxychains=""

  if [ -n "${TOR_HOST}" ]; then
    proxychains="PROXYCHAINS_ONE_PROXY='socks5 `getent hosts ${TOR_HOST} | awk '{ print $1 }'` ${TOR_PORT}' proxychains4"
  fi

  # Let's create the OTS file locally from the base64
  trace "[verify] Creating /otsfiles/otsfile-$$.ots"
  echo "${base64otsfile}" | base64 -d > /otsfiles/otsfile-$$.ots

  if [ "${TESTNET}" -eq "1" ]; then
    trace "[verify] ${proxychains} ots-cli.js -l \"https://testnet.calendar.kexkey.com/\" --no-default-whitelist verify -d ${hash} /otsfiles/otsfile-$$.ots"
    result=$(sh -c "${proxychains} ots-cli.js -l 'https://testnet.calendar.kexkey.com/' --no-default-whitelist verify -d ${hash} /otsfiles/otsfile-$$.ots 2>&1")
    returncode=$?
  else
    trace "[verify] ${proxychains} ots-cli.js verify -d ${hash} /otsfiles/otsfile-$$.ots"
    result=$(sh -c "${proxychains} ots-cli.js verify -d ${hash} /otsfiles/otsfile-$$.ots 2>&1")
    returncode=$?
  fi
  trace_rc ${returncode}
  trace "[verify] result=${result}"

  trace "[verify] Removing temporary file /otsfiles/otsfile-$$.ots..."
  rm /otsfiles/otsfile-$$.ots

  # /script $ ots-cli.js -v v -d 7d694f669d6da235a5fb9ef8c89da55e30b59eb662a7131f85344d798fc3280c /otsfiles/Order_10019_1543447088465.ots
  # Assuming target hash is '7d694f669d6da235a5fb9ef8c89da55e30b59eb662a7131f85344d798fc3280c'
  # Success! Bitcoin block 551876 attests existence as of 2018-11-28 GMT

  # /script $ ots-cli.js -v v -d 7d694f669d6da235a5fb9ef8c89da55e30b59eb662a7131f85344d798fc3280c /otsfiles/Order_10019_1543447088465_incomplete.ots
  # Assuming target hash is '7d694f669d6da235a5fb9ef8c89da55e30b59eb662a7131f85344d798fc3280c'
  # Got 1 attestation(s) from https://bob.btc.calendar.opentimestamps.org
  # Got 1 attestation(s) from https://finney.calendar.eternitywall.com
  # Got 1 attestation(s) from https://alice.btc.calendar.opentimestamps.org
  # Got 1 attestation(s) from https://btc.calendar.catallaxy.com
  # Success! Bitcoin block 551876 attests existence as of 2018-11-28 GMT

  # /script # ots-cli.js -v v -d 3eb3df18d9f8ee502c77f3b231818988c2c1cd44baa39e663d14708a7053d531 aaa
  # Assuming target hash is '3eb3df18d9f8ee502c77f3b231818988c2c1cd44baa39e663d14708a7053d531'
  # Calendar https://btc.calendar.catallaxy.com: Pending confirmation in Bitcoin blockchain
  # Calendar https://alice.btc.calendar.opentimestamps.org: Pending confirmation in Bitcoin blockchain
  # Calendar https://bob.btc.calendar.opentimestamps.org: Pending confirmation in Bitcoin blockchain
  # Calendar https://finney.calendar.eternitywall.com: Pending confirmation in Bitcoin blockchain

  # /script # ots-cli.js -v v -d 3eb3df18d9f8ee502c77f3b231818988c2c1cd44baa39e663d14708a7053d531 allo
  # Assuming target hash is '3eb3df18d9f8ee502c77f3b231818988c2c1cd44baa39e663d14708a7053d531'
  # Error! allo is not a timestamp file.

  # /script # ots-cli.js -v v -d 3eb3df18d9f8ee502c77f3b231818988c2c1cd44baa39e663d14708a7053d53 aaa
  # Assuming target hash is '3eb3df18d9f8ee502c77f3b231818988c2c1cd44baa39e663d14708a7053d53'
  # Expected digest 3eb3df18d9f8ee502c77f3b231818988c2c1cd44baa39e663d14708a7053d531
  # File does not match original!
  # File does not match original!

  # Let's send one of those possible outcomes:
  # - If last line begins with "Success!": Success + block height
  # - If "Pending confirmation in Bitcoin blockchain" found: Pending
  # - Otherwise: Error +
  #   - Error! allo is not a timestamp file.
  #   - File does not match original!
  #   - Whatever the last line output is

  data="{\"method\":\"verify\",\"hash\":\"${hash}\",\"result\":\""

  trace "[verify] grepping..."
  echo "${result}" | grep "Success!" > /dev/null
  returncode=$?
  trace_rc ${returncode}

  if [ "${returncode}" -eq "0" ]; then
    # "Success!" found
    data="${data}success"
  else
    # "Success!" not found
    echo "${result}" | grep "Pending" > /dev/null
    returncode=$?
    trace_rc ${returncode}

    if [ "${returncode}" -eq "0" ]; then
      # "Pending" found
      data="${data}pending"
    else
      # "Pending" not found
      data="${data}error"
    fi
  fi

  data="${data}\",\"message\":\"${result}\"}"

  trace "[verify] data=${data}"

  echo "${data}"

  return ${returncode}
}

info() {
  trace "Entering info()..."

  local request=${1}
  local base64otsfile=$(echo "${request}" | jq ".base64otsfile" | tr -d '"')
  trace "[info] base64otsfile=${base64otsfile}"

  local result
  local returncode
  local message
  local data

  # Let's create the OTS file locally from the base64
  trace "[info] Creating /otsfiles/otsfile-$$.ots"
  echo "${base64otsfile}" | base64 -d > /otsfiles/otsfile-$$.ots

  trace "[info] ots-cli.js info /otsfiles/otsfile-$$.ots"
  result=$(ots-cli.js info /otsfiles/otsfile-$$.ots 2>&1 | base64 | tr -d '\n')
  returncode=$?
  trace_rc ${returncode}
  trace "[info] result=${result}"

  trace "[info] Removing temporary file /otsfiles/otsfile-$$.ots..."
  rm /otsfiles/otsfile-$$.ots

  # /otsfiles # ots-cli.js info a2d4ff9c70b7b884e04e04c184a7bf8a07dca029a68efa4d0477cea0c6f8ac2b.ots
  # File sha256 hash: a2d4ff9c70b7b884e04e04c184a7bf8a07dca029a68efa4d0477cea0c6f8ac2b
  # Timestamp:
  # append 0736f76dfd242f5156321c561d11ef47
  # sha256
  #  -> append 4820230d20f302a17a45f0de0e3e23a6
  #     sha256
  #     prepend 5d5da8e6
  #     append 8b6d6af19f6ac839
  #     verify PendingAttestation('https://alice.btc.calendar.opentimestamps.org')
  #  -> append 9c5e80c7251b313b180acc6e2341d9de
  #     sha256
  #     prepend 5d5da8e6
  #     append 59d56c4ad5d8d6e4
  #     verify PendingAttestation('https://bob.btc.calendar.opentimestamps.org')
  #  -> append a437fa964b029950dc8f507de448cd08
  #     sha256
  #     prepend 5d5da8e6
  #     append d25542b20883d479
  #     verify PendingAttestation('https://finney.calendar.eternitywall.com')
  #  -> append a34c1ae4a38e776450a643d298abf428
  #     sha256
  #     prepend 5d5da8e7
  #     append 60ed070138239971
  #     verify PendingAttestation('https://btc.calendar.catallaxy.com')

  data="{\"method\":\"info\",\"result\":\"${result}\"}"
  trace "[info] data=${data}"

  echo "${data}"

  return ${returncode}
}
