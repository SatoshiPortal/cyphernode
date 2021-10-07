PRAGMA foreign_keys = ON;

CREATE TABLE rawtx (
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
CREATE INDEX idx_rawtx_timereceived ON rawtx (timereceived);
CREATE INDEX idx_rawtx_fee ON rawtx (fee);
CREATE INDEX idx_rawtx_size ON rawtx (size);
CREATE INDEX idx_rawtx_vsize ON rawtx (vsize);
CREATE INDEX idx_rawtx_blockhash ON rawtx (blockhash);
CREATE INDEX idx_rawtx_blockheight ON rawtx (blockheight);
CREATE INDEX idx_rawtx_blocktime ON rawtx (blocktime);
CREATE INDEX idx_rawtx_confirmations ON rawtx (confirmations);
