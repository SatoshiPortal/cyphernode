PRAGMA foreign_keys = ON;

CREATE TABLE watching_by_descriptor (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  descriptor TEXT UNIQUE,
  label TEXT UNIQUE,
  callback0conf TEXT,
  callback1conf TEXT,
  last_imported_n INTEGER,
  watching INTEGER DEFAULT FALSE,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE watching ADD COLUMN watching_by_descriptor_id INTEGER REFERENCES watching_by_descriptor;

