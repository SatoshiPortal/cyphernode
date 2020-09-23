PRAGMA foreign_keys=off;

BEGIN TRANSACTION;

CREATE TABLE batcher (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  label TEXT UNIQUE,
  conf_target INTEGER,
  feerate REAL,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO batcher (id, label, conf_target, feerate) VALUES (1, "default", 6, NULL);

ALTER TABLE recipient ADD COLUMN webhook_url TEXT;
ALTER TABLE recipient ADD COLUMN batcher_id INTEGER REFERENCES batcher;
ALTER TABLE recipient ADD COLUMN label INTEGER REFERENCES batcher;
ALTER TABLE recipient ADD COLUMN calledback INTEGER DEFAULT FALSE;
ALTER TABLE recipient ADD COLUMN calledback_ts INTEGER;
CREATE INDEX idx_recipient_label ON recipient (label);

ALTER TABLE tx ADD COLUMN conf_target INTEGER DEFAULT NULL;


ALTER TABLE watching RENAME TO watching_20200610;

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

INSERT INTO watching SELECT * FROM watching_20200610;

DROP INDEX IF EXISTS idx_watching_address;
CREATE INDEX idx_watching_address ON watching (address);
DROP INDEX IF EXISTS idx_watching_01;
CREATE UNIQUE INDEX idx_watching_01 ON watching (address, callback0conf, callback1conf);

--DROP TABLE watching20200610;

ALTER TABLE watching_by_txid RENAME TO watching_by_txid_20200610;

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

INSERT INTO watching_by_txid SELECT * FROM watching_by_txid_20200610;

DROP INDEX IF EXISTS idx_watching_by_txid_txid;
CREATE INDEX idx_watching_by_txid_txid ON watching_by_txid (txid);
DROP INDEX IF EXISTS idx_watching_by_txid_1x;
CREATE UNIQUE INDEX idx_watching_by_txid_1x ON watching_by_txid (txid, callback1conf, callbackxconf);

--DROP TABLE watching_by_txid_20200610;

COMMIT;

PRAGMA foreign_keys=on;
