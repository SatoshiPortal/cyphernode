PRAGMA foreign_keys = ON;

INSERT INTO cyphernode_props (property, value) VALUES ("pay_index", "0");

CREATE TABLE ln_invoice (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bolt11 TEXT UNIQUE,
  status TEXT,
  callback_url TEXT,
  calledback INTEGER DEFAULT FALSE,
  callback_failed INTEGER DEFAULT FALSE,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_lninvoice_bolt11 ON ln_invoice (bolt11);
CREATE INDEX idx_lninvoice_status ON ln_invoice (status);
