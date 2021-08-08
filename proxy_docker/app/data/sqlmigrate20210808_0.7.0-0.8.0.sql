PRAGMA foreign_keys=off;

BEGIN TRANSACTION;

ALTER TABLE watching ADD COLUMN label TEXT;

COMMIT;

PRAGMA foreign_keys=on;
