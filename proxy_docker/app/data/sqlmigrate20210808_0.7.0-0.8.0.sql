PRAGMA foreign_keys=off;

BEGIN TRANSACTION;

ALTER TABLE watching ADD COLUMN label TEXT;
CREATE INDEX idx_watching_label ON watching (label);

COMMIT;

PRAGMA foreign_keys=on;
