
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
