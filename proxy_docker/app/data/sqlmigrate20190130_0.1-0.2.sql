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
CREATE INDEX idx_watching_by_pub32_pub32 ON watching_by_pub32 (pub32);
CREATE INDEX idx_watching_by_pub32_label ON watching_by_pub32 (label);

ALTER TABLE watching ADD COLUMN watching_by_pub32_id INTEGER REFERENCES watching_by_pub32;
ALTER TABLE watching ADD COLUMN pub32_index INTEGER;
