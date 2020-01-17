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

-- for all duplicate addresses, we only keep the last one inserted
DELETE FROM watching WHERE id NOT IN (SELECT MAX(id) FROM watching GROUP BY address);
DROP INDEX idx_watching_address;
CREATE UNIQUE INDEX idx_watching_address ON watching(address);

ALTER TABLE watching ADD COLUMN watching_by_pub32_id INTEGER REFERENCES watching_by_pub32;
ALTER TABLE watching ADD COLUMN pub32_index INTEGER;
