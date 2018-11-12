PRAGMA foreign_keys = ON;

CREATE TABLE watching (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  address TEXT,
  watching INTEGER DEFAULT FALSE,
  callback0conf TEXT,
  calledback0conf INTEGER DEFAULT FALSE,
  callback1conf TEXT,
  calledback1conf INTEGER DEFAULT FALSE,
  imported INTEGER DEFAULT FALSE,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_watching_address ON watching (address);

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
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_recipient_address ON recipient (address);

CREATE TABLE stamp (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  hash TEXT UNIQUE,
  callbackUrl TEXT,
  requested INTEGER DEFAULT FALSE,
  upgraded INTEGER DEFAULT FALSE,
  calledback INTEGER DEFAULT FALSE,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
