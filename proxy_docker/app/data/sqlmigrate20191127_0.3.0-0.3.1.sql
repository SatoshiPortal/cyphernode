ALTER TABLE recipient ADD COLUMN wallet_name TEXT;

CREATE INDEX idx_recipient_wallet_name ON recipient (wallet_name);
