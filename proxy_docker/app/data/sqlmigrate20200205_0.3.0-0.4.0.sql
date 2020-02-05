PRAGMA foreign_keys = ON;

CREATE TABLE elements_watching (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  address TEXT UNIQUE,
  watching INTEGER DEFAULT FALSE,
  callback0conf TEXT,
  calledback0conf INTEGER DEFAULT FALSE,
  callback1conf TEXT,
  calledback1conf INTEGER DEFAULT FALSE,
  imported INTEGER DEFAULT FALSE,
  event_message TEXT,
  assetid TEXT,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE elements_watching_tx (
  elements_watching_id INTEGER REFERENCES elements_watching,
  elements_tx_id INTEGER REFERENCES elements_tx,
  vout INTEGER,
  amount REAL
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
  assetid TEXT,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_elements_tx_timereceived ON elements_tx (timereceived);
CREATE INDEX idx_elements_tx_fee ON elements_tx (fee);
CREATE INDEX idx_elements_tx_size ON elements_tx (size);
CREATE INDEX idx_elements_tx_vsize ON elements_tx (vsize);
CREATE INDEX idx_elements_tx_blockhash ON elements_tx (blockhash);
CREATE INDEX idx_elements_tx_blockheight ON elements_tx (blockheight);
CREATE INDEX idx_elements_tx_blocktime ON elements_tx (blocktime);
CREATE INDEX idx_elements_tx_assetid ON elements_tx (assetid);

CREATE TABLE elements_recipient (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  address TEXT,
  amount REAL,
  tx_id INTEGER REFERENCES elements_tx,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_elements_recipient_address ON elements_recipient (address);
