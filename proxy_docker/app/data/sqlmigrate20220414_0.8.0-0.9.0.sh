#!/bin/sh

. ./trace.sh

# Current table definition
#
# psql -qAtX -h postgres -U cyphernode -c "\d cyphernode_props"
# id|integer||not null|nextval('cyphernode_props_id_seq'::regclass)
# property|character varying|||
# value|character varying|||
# inserted_ts|timestamp without time zone|||CURRENT_TIMESTAMP
#
# values:
#  psql -qAtX -h postgres -U cyphernode -c "select * from cyphernode_props"
#  1|version|0.1|2022-04-14 15:06:06.611664
#  2|pay_index|0|2022-04-14 15:06:06.611664
#
# 

SCRIPT_NAME="sqlmigrate20211105_0.8.0-0.9.0.sh"

trace "[$SCRIPT_NAME] Checking if column 'category' is in table ..."
table_descr=$(psql -qAtX -h postgres -U cyphernode -c "\d cyphernode_props")
category_col=$(echo $table_descr | grep 'category|character varying')
returncode=$?
if [ -z "$category_col" ]; then
  
  SQL_ST="ALTER TABLE cyphernode_props ADD COLUMN category VARCHAR"
  trace "[$SCRIPT_NAME] $SQL_ST"
  psql -qAtX -h postgres -U cyphernode -c "$SQL_ST"
  returncode=$?
  trace_rc ${returncode}

  SQL_ST="UPDATE cyphernode_props SET category='cyphernode', value='0.2' WHERE property='version'"
  trace "[$SCRIPT_NAME] $SQL_ST"
  psql -qAtX -h postgres -U cyphernode -c "$SQL_ST"
  returncode=$?
  trace_rc ${returncode}

  SQL_ST="UPDATE cyphernode_props SET category='c-lightning' WHERE property='pay_index'"
  trace "[$SCRIPT_NAME] $SQL_ST"
  psql -qAtX -h postgres -U cyphernode -c "$SQL_ST"
  returncode=$?
  trace_rc ${returncode}
  
  SQL_ST="DROP INDEX idx_cp_property"
  trace "[$SCRIPT_NAME] $SQL_ST"
  psql -qAtX -h postgres -U cyphernode -c "$SQL_ST"
  returncode=$?
  trace_rc ${returncode}

  SQL_ST="DROP INDEX idx_cp_propval"
  trace "[$SCRIPT_NAME] $SQL_ST"
  psql -qAtX -h postgres -U cyphernode -c "$SQL_ST"
  returncode=$?
  trace_rc ${returncode}
  
  SQL_ST="CREATE UNIQUE INDEX idx_cp_catprop ON cyphernode_props (category, property)"
  trace "[$SCRIPT_NAME] $SQL_ST"
  psql -qAtX -h postgres -U cyphernode -c "$SQL_ST"
  returncode=$?
  trace_rc ${returncode}

  SQL_ST="ALTER TABLE cyphernode_props ALTER COLUMN category SET NOT NULL"
  trace "[$SCRIPT_NAME] $SQL_ST"
  psql -qAtX -h postgres -U cyphernode -c "$SQL_ST"
  returncode=$?
  trace_rc ${returncode}
  
  SQL_ST="ALTER TABLE cyphernode_props ALTER COLUMN property SET NOT NULL"
  trace "[$SCRIPT_NAME] $SQL_ST"
  psql -qAtX -h postgres -U cyphernode -c "$SQL_ST"
  returncode=$?
  trace_rc ${returncode}

  trace_rc ${returncode}
  [ "${returncode}" -eq "0" ] || exit ${returncode}

else
  trace "[$SCRIPT_NAME] Column 'category' already there, skipping!"
fi
