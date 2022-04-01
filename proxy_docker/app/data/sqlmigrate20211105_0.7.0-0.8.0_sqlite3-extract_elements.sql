.output sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extracted-data-elements.sql
select "BEGIN;";
.headers on
.mode insert elements_watching_by_pub32
select id,pub32,label,derivation_path,callback0conf,callback1conf,last_imported_n,case when watching=1 then 'TRUE' else 'FALSE' end as watching,inserted_ts from elements_watching_by_pub32;
.mode insert elements_watching
select id,address,label,unblinded_address,case when watching=1 then 'TRUE' else 'FALSE' end as watching,callback0conf,case when calledback0conf=1 then 'TRUE' else 'FALSE' end as calledback0conf,callback1conf,case when calledback1conf=1 then 'TRUE' else 'FALSE' end as calledback1conf,case when imported=1 then 'TRUE' else 'FALSE' end as imported,watching_by_pub32_id as elements_watching_by_pub32_id,pub32_index,event_message,watching_assetid,inserted_ts from elements_watching;
.mode insert elements_tx
select id,txid,hash,confirmations,timereceived,fee,size,vsize,case when is_replaceable=1 then 'TRUE' else 'FALSE' end as is_replaceable,blockhash,blockheight,blocktime,inserted_ts from elements_tx;
.mode insert elements_watching_tx
select * from elements_watching_tx;
.mode insert elements_recipient
select id,address,unblinded_address,amount,assetid,tx_id as elements_tx_id,inserted_ts,label from elements_recipient;
.mode insert elements_watching_by_txid
select id,txid,case when watching=1 then 'TRUE' else 'FALSE' end as watching,callback1conf,case when calledback1conf=1 then 'TRUE' else 'FALSE' end as calledback1conf,callbackxconf,case when calledbackxconf=1 then 'TRUE' else 'FALSE' end as calledbackxconf,nbxconf,inserted_ts from elements_watching_by_txid;
.quit
