PRAGMA foreign_keys = ON;

CREATE TABLE watching_by_pub32 (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pub32 TEXT UNIQUE,
  label TEXT UNIQUE,
  derivation_path TEXT,
  callback0conf TEXT,
  callback1conf TEXT,
  last_imported_n INTEGER,
  watching INTEGER DEFAULT FALSE,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE watching (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  address TEXT,
  watching INTEGER DEFAULT FALSE,
  callback0conf TEXT,
  calledback0conf INTEGER DEFAULT FALSE,
  callback1conf TEXT,
  calledback1conf INTEGER DEFAULT FALSE,
  imported INTEGER DEFAULT FALSE,
  watching_by_pub32_id INTEGER REFERENCES watching_by_pub32,
  pub32_index INTEGER,
  event_message TEXT,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_watching_address ON watching (address);
CREATE UNIQUE INDEX idx_watching_01 ON watching (address, callback0conf, callback1conf);

CREATE TABLE watching_tx (
  watching_id INTEGER REFERENCES watching,
  tx_id INTEGER REFERENCES tx,
  vout INTEGER,
  amount REAL
);
CREATE UNIQUE INDEX idx_watching_tx ON watching_tx (watching_id, tx_id);

CREATE TABLE tx (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  txid TEXT UNIQUE,
  hash TEXT UNIQUE,
  confirmations INTEGER DEFAULT 0,
  timereceived INTEGER,
  fee REAL,
  size INTEGER,
  vsize INTEGER,
	is_replaceable INTEGER,
  blockhash TEXT,
  blockheight INTEGER,
  blocktime INTEGER,
  conf_target INTEGER,
  raw_tx TEXT,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_tx_timereceived ON tx (timereceived);
CREATE INDEX idx_tx_fee ON tx (fee);
CREATE INDEX idx_tx_size ON tx (size);
CREATE INDEX idx_tx_vsize ON tx (vsize);
CREATE INDEX idx_tx_blockhash ON tx (blockhash);
CREATE INDEX idx_tx_blockheight ON tx (blockheight);
CREATE INDEX idx_tx_blocktime ON tx (blocktime);

CREATE TABLE recipient (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  address TEXT,
  amount REAL,
  tx_id INTEGER REFERENCES tx,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP,
  webhook_url TEXT,
  calledback INTEGER DEFAULT FALSE,
  calledback_ts INTEGER,
  batcher_id INTEGER REFERENCES batcher,
  label TEXT
);
CREATE INDEX idx_recipient_address ON recipient (address);
CREATE INDEX idx_recipient_label ON recipient (label);

CREATE TABLE batcher (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  label TEXT UNIQUE,
  conf_target INTEGER,
  feerate REAL,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO batcher (id, label, conf_target, feerate) VALUES (1, "default", 6, NULL);

CREATE TABLE watching_by_txid (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  txid TEXT,
  watching INTEGER DEFAULT FALSE,
  callback1conf TEXT,
  calledback1conf INTEGER DEFAULT FALSE,
  callbackxconf TEXT,
  calledbackxconf INTEGER DEFAULT FALSE,
  nbxconf INTEGER,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_watching_by_txid_txid ON watching_by_txid (txid);
CREATE UNIQUE INDEX idx_watching_by_txid_1x ON watching_by_txid (txid, callback1conf, callbackxconf);

CREATE TABLE stamp (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  hash TEXT UNIQUE,
  callbackUrl TEXT,
  requested INTEGER DEFAULT FALSE,
  upgraded INTEGER DEFAULT FALSE,
  calledback INTEGER DEFAULT FALSE,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_stamp_calledback ON stamp (calledback);

CREATE TABLE cyphernode_props (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  property TEXT,
  value TEXT,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_cp_property ON cyphernode_props (property);

INSERT INTO cyphernode_props (property, value) VALUES ("version", "0.1");
INSERT INTO cyphernode_props (property, value) VALUES ("pay_index", "0");

CREATE TABLE ln_invoice (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  label TEXT UNIQUE,
  bolt11 TEXT UNIQUE,
  payment_hash TEXT,
  msatoshi INTEGER,
  status TEXT,
  pay_index INTEGER,
  msatoshi_received INTEGER,
  paid_at INTEGER,
  description TEXT,
  expires_at INTEGER,
  callback_url TEXT,
  calledback INTEGER DEFAULT FALSE,
  callback_failed INTEGER DEFAULT FALSE,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_lninvoice_label ON ln_invoice (label);
CREATE INDEX idx_lninvoice_bolt11 ON ln_invoice (bolt11);

CREATE TABLE elements_watching_by_pub32 (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pub32 TEXT UNIQUE,
  label TEXT UNIQUE,
  derivation_path TEXT,
  callback0conf TEXT,
  callback1conf TEXT,
  last_imported_n INTEGER,
  watching INTEGER DEFAULT FALSE,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE elements_watching (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  address TEXT UNIQUE,
  unblinded_address TEXT UNIQUE,
  watching INTEGER DEFAULT FALSE,
  callback0conf TEXT,
  calledback0conf INTEGER DEFAULT FALSE,
  callback1conf TEXT,
  calledback1conf INTEGER DEFAULT FALSE,
  imported INTEGER DEFAULT FALSE,
  watching_by_pub32_id INTEGER REFERENCES elements_watching_by_pub32,
  pub32_index INTEGER,
  event_message TEXT,
  watching_assetid TEXT,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE elements_watching_tx (
  elements_watching_id INTEGER REFERENCES elements_watching,
  elements_tx_id INTEGER REFERENCES elements_tx,
  vout INTEGER,
  amount REAL,
  assetid TEXT
);
CREATE UNIQUE INDEX idx_elements_watching_tx ON elements_watching_tx (elements_watching_id, elements_tx_id);

CREATE TABLE elements_tx (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  txid TEXT UNIQUE,
  hash TEXT UNIQUE,
  confirmations INTEGER DEFAULT 0,
  timereceived INTEGER,
  fee REAL,
  size INTEGER,
  vsize INTEGER,
	is_replaceable INTEGER,
  blockhash TEXT,
  blockheight INTEGER,
  blocktime INTEGER,
  raw_tx TEXT,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_elements_tx_timereceived ON elements_tx (timereceived);
CREATE INDEX idx_elements_tx_fee ON elements_tx (fee);
CREATE INDEX idx_elements_tx_size ON elements_tx (size);
CREATE INDEX idx_elements_tx_vsize ON elements_tx (vsize);
CREATE INDEX idx_elements_tx_blockhash ON elements_tx (blockhash);
CREATE INDEX idx_elements_tx_blockheight ON elements_tx (blockheight);
CREATE INDEX idx_elements_tx_blocktime ON elements_tx (blocktime);

CREATE TABLE elements_recipient (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  address TEXT,
  unblinded_address TEXT,
  amount REAL,
  assetid TEXT,
  tx_id INTEGER REFERENCES elements_tx,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_elements_recipient_address ON elements_recipient (address);
CREATE INDEX idx_elements_recipient_unblinded_address ON elements_recipient (unblinded_address);
CREATE INDEX idx_elements_recipient_assetid ON elements_recipient (assetid);

CREATE TABLE elements_watching_by_txid (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  txid TEXT UNIQUE,
  watching INTEGER DEFAULT FALSE,
  callback1conf TEXT,
  calledback1conf INTEGER DEFAULT FALSE,
  callbackxconf TEXT,
  calledbackxconf INTEGER DEFAULT FALSE,
  nbxconf INTEGER,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_elements_watching_by_txid_txid ON elements_watching_by_txid (txid);
