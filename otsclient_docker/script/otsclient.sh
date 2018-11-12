#!/bin/sh

. ./trace.sh

stamp()
{
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
    # String nor found
    data="${data}error\",\"error\":\"${result}\"}"
  fi

  trace "[stamp] data=${data}"

  echo "${data}"

  return ${returncode}
}

upgrade()
{
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
