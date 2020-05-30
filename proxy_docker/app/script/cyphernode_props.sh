#!/bin/sh

. ./trace.sh
. ./sql.sh

cyphernode_props_get_props(){
  trace "Entering get_props()"
  local props
  props=$(sql "SELECT * FROM cyphernode_props")
  returncode=$?
  trace_rc ${returncode}
  props_json=$(echo "$props" | jq -Rcsn '
  {"cyphernode_props":
    [inputs
     | . / "\n"
     | (.[] | select(length > 0) | . / "|") as $input
     | {"id": $input[0], "property": $input[1], "value" : $input[2], "inserted_ts": $input[3]}
    ]
  }
  ')
  echo "$props_json"
  return ${returncode}
}

cyphernode_props_upsert_prop(){
  local request=${1}
  local returncode
  trace "Entering cyphernode_props_upsert_prop() with $request"
  property=$(echo "${request}" | jq -r ".property")
  value=$(echo "${request}" | jq -r ".value")
  if [ "${property}" = "null" ]; then
    trace "[upsert_prop] property field is required"
    return 1
  fi
  if [ "${value}" = "null" ]; then
    trace "[upsert_prop] value field is required"
    return 1
  fi
  # cyphernode_props table has no UNIQUE constraint on property field, so we have to do the upsert check  manully rather than use ON CONFLICT
  property_id=$(sql "SELECT id FROM cyphernode_props WHERE property='$property'")
  trace "Property id $property_id"
  if [ -z "$property_id" ]; then
       $(sql "INSERT INTO cyphernode_props (property,value) VALUES ('$property','$value')")
       trace "[upsert_prop] Inserted prop $property, with value: $value, insert id: $upsert_id"
  else
       $(sql "UPDATE cyphernode_props SET value='$value' WHERE id=${property_id}")
       trace "[upsert_prop] Updated prop $property, with value: $value"
  fi
  returncode=$?
  trace_rc ${returncode}
  echo "{\"result\": \"success\"}"
  return ${returncode}
}
