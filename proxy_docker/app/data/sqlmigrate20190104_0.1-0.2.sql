PRAGMA foreign_keys = ON;

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

CREATE TABLE watching_by_txid (
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
CREATE INDEX idx_watching_by_txid_txid ON watching_by_txid (txid);
