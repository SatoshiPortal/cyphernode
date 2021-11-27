.output sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extracted-data.sql
select "BEGIN;";
.headers on
.mode insert watching_by_pub32
select id,pub32,label,derivation_path,callback0conf,callback1conf,last_imported_n,case when watching=1 then 'TRUE' else 'FALSE' end as watching,inserted_ts from watching_by_pub32;
.mode insert watching
select id,address,label,case when watching=1 then 'TRUE' else 'FALSE' end as watching,callback0conf,case when calledback0conf=1 then 'TRUE' else 'FALSE' end as calledback0conf,callback1conf,case when calledback1conf=1 then 'TRUE' else 'FALSE' end as calledback1conf,case when imported=1 then 'TRUE' else 'FALSE' end as imported,watching_by_pub32_id,pub32_index,event_message,inserted_ts from watching;
.mode insert tx
select id,txid,hash,confirmations,timereceived,fee,size,vsize,case when is_replaceable=1 then 'TRUE' else 'FALSE' end as is_replaceable,blockhash,blockheight,blocktime,conf_target,inserted_ts from tx;
.mode insert watching_tx
select * from watching_tx;
.mode insert batcher
select * from batcher;
.mode insert recipient
select id,address,amount,tx_id,inserted_ts,webhook_url,case when calledback=1 then 'TRUE' else 'FALSE' end as calledback,calledback_ts,batcher_id,label from recipient;
.mode insert watching_by_txid
select id,txid,case when watching=1 then 'TRUE' else 'FALSE' end as watching,callback1conf,case when calledback1conf=1 then 'TRUE' else 'FALSE' end as calledback1conf,callbackxconf,case when calledbackxconf=1 then 'TRUE' else 'FALSE' end as calledbackxconf,nbxconf,inserted_ts from watching_by_txid;
.mode insert stamp
select id,hash,callbackUrl,case when requested=1 then 'TRUE' else 'FALSE' end as requested,case when upgraded=1 then 'TRUE' else 'FALSE' end as upgraded,case when calledback=1 then 'TRUE' else 'FALSE' end as calledback,inserted_ts from stamp;
.mode insert ln_invoice
select id,label,bolt11,payment_hash,msatoshi,status,pay_index,msatoshi_received,paid_at,description,expires_at,callback_url,case when calledback=1 then 'TRUE' else 'FALSE' end as calledback,case when callback_failed=1 then 'TRUE' else 'FALSE' end as callback_failed,inserted_ts from ln_invoice;
-- cyphernode_props rows were already inserted in db creation, let's update them here
.headers off
.mode list cyphernode_props
select 'update cyphernode_props set value=''' || value || ''', inserted_ts=''' || inserted_ts || ''' where id=' || id || ';' from cyphernode_props;
.quit
