#!/bin/sh

. ./trace.sh

# Calls barkd's REST API with the bearer token from BARKD_TOKEN_FILE.
#
# The token goes through a curl config file so it never appears on a command
# line. The file is written on first use because barkd may start after the
# proxy.

barkd_curl_cfg() {
  if [ ! -s "${BARKD_CURL_CFG}" ]; then
    if [ ! -s "${BARKD_TOKEN_FILE}" ]; then
      trace "[barkd_curl_cfg] token file ${BARKD_TOKEN_FILE} not found"
      return 1
    fi
    umask 077
    printf 'header = "Authorization: Bearer %s"\n' "$(cat "${BARKD_TOKEN_FILE}")" > "${BARKD_CURL_CFG}"
  fi
  return 0
}

# barkd_call <GET|POST|DELETE> <path under /api/v1> [json body]
#
# Prints the response body. Returns 0 on HTTP 2xx, 1 on a transport failure
# (nothing printed), or 2 on an HTTP error (barkd's JSON error body is
# printed). The HTTP status is kept in a per-process file, read back by
# barkd_http_code, because callers run this in a command substitution and a
# shell return code cannot carry a status above 255.
barkd_http_code_file() {
  printf '/tmp/barkd_http_code.%s' "$$"
}

barkd_http_code() {
  cat "$(barkd_http_code_file)" 2>/dev/null
}

trap 'rm -f "$(barkd_http_code_file)"' EXIT

barkd_call() {
  trace "Entering barkd_call()..."

  local method=${1}
  local path=${2}
  local body=${3}
  local output
  local http_code
  local returncode

  rm -f "$(barkd_http_code_file)"
  barkd_curl_cfg || return 1

  trace "[barkd_call] ${method} ${BARKD_URL}/api/v1${path} body=${body}"
  if [ -n "${body}" ]; then
    output=$(curl -s -K "${BARKD_CURL_CFG}" -X "${method}" -H "Content-Type: application/json" \
      --data "${body}" --max-time "${BARKD_TIMEOUT:-300}" -w '\n%{http_code}' "${BARKD_URL}/api/v1${path}")
  else
    output=$(curl -s -K "${BARKD_CURL_CFG}" -X "${method}" \
      --max-time "${BARKD_TIMEOUT:-300}" -w '\n%{http_code}' "${BARKD_URL}/api/v1${path}")
  fi
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    trace "[barkd_call] curl failed with ${returncode}"
    return 1
  fi

  http_code=$(printf '%s' "${output}" | tail -n 1)
  printf '%s' "${output}" | sed '$d'
  trace "[barkd_call] http_code=${http_code}"
  printf '%s' "${http_code}" > "$(barkd_http_code_file)"

  case "${http_code}" in
    2*) return 0 ;;
    *) return 2 ;;
  esac
}

# Wraps a barkd error body into Cyphernode's error envelope. The first
# argument is barkd_call's return code; the HTTP status, when there is one,
# replaces it.
barkd_error() {
  local http_code
  local body=${2}
  local message

  http_code=$(barkd_http_code)
  [ -z "${http_code}" ] && http_code=${1}

  message=$(printf '%s' "${body}" | jq -r '.message // .error // empty' 2>/dev/null)
  [ -z "${message}" ] && message="barkd request failed"
  jq -cn --argjson code "${http_code}" --arg message "${message}" '{error: {code: $code, message: $message}}'
}
