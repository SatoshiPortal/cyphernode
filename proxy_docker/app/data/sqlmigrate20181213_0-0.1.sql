PRAGMA foreign_keys = ON;

CREATE TABLE stamp (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  hash TEXT UNIQUE,
  callbackUrl TEXT,
  requested INTEGER DEFAULT FALSE,
  upgraded INTEGER DEFAULT FALSE,
  calledback INTEGER DEFAULT FALSE,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_stamp_hash ON stamp (hash);
CREATE INDEX idx_stamp_calledback ON stamp (calledback);

CREATE TABLE cyphernode_props (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  property TEXT,
  value TEXT,
  inserted_ts INTEGER DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_cp_property ON cyphernode_props (property);

INSERT INTO cyphernode_props (property, value) VALUES ("version", "0.1");
