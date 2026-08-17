PRAGMA foreign_keys=off;

BEGIN TRANSACTION;

ALTER TABLE elements_watching ADD COLUMN label TEXT;
CREATE INDEX idx_elements_watching_label ON elements_watching (label);
ALTER TABLE elements_recipient ADD COLUMN label TEXT;

COMMIT;

PRAGMA foreign_keys=on;
