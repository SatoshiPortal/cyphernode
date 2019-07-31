#!/bin/sh

. ./trace.sh

stamp() {
  trace "Entering stamp()..."

  local hash=${1}
  trace "[stamp] hash=${hash}"

  local result
  local returncode
  local data

  trace "[stamp] ots-cli.js stamp -d ${hash}"
  result=$(cd /otsfiles && ots-cli.js stamp -d ${hash} 2>&1)
  returncode=$?
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

  trace "[upgrade] ots-cli.js upgrade ${hash}.ots"
  result=$(cd /otsfiles && ots-cli.js upgrade ${hash}.ots 2>&1)
  returncode=$?
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
  local data

  # Let's create the OTS file locally from the base64
  trace "[verify] Creating /otsfiles/otsfile-$$.ots"
  echo "${base64otsfile}" > /otsfiles/otsfile-$$.ots
  trace "[verify] ots-cli.js verify -d ${hash} /otsfiles/otsfile-$$.ots"
  result=$(ots-cli.js verify -d ${hash} /otsfiles/otsfile-$$.ots 2>&1)
  returncode=$?
  trace_rc ${returncode}
  trace "[verify] result=${result}"

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
    # String found
    data="${data}success\"}"
  else
    # String not found
    data="${data}error\",\"error\":\"${result}\"}"
  fi

  trace "[verify] data=${data}"

  echo "${data}"

  return ${returncode}
}
