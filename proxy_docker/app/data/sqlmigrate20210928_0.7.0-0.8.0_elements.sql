PRAGMA foreign_keys=off;

BEGIN TRANSACTION;

CREATE INDEX idx_elements_watching_watching ON elements_watching (watching);
CREATE INDEX idx_elements_watching_imported ON elements_watching (imported);
CREATE INDEX idx_elements_watching_watching_by_pub32_id ON elements_watching (watching_by_pub32_id);
CREATE INDEX idx_elements_watching_address ON elements_watching (address);
CREATE UNIQUE INDEX idx_elements_watching_01 ON elements_watching (address, callback0conf, callback1conf);
CREATE INDEX idx_elements_watching_tx_watching_id ON elements_watching_tx (elements_watching_id);
CREATE INDEX idx_elements_watching_tx_tx_id ON elements_watching_tx (elements_tx_id);
CREATE INDEX idx_elements_tx_confirmations ON elements_tx (confirmations);
CREATE UNIQUE INDEX idx_elements_watching_by_txid_1x ON elements_watching_by_txid (txid, callback1conf, callbackxconf);
CREATE INDEX idx_elements_watching_by_txid_watching ON elements_watching_by_txid (watching);
CREATE INDEX idx_elements_watching_by_txid_callback1conf ON elements_watching_by_txid (callback1conf);
CREATE INDEX idx_elements_watching_by_txid_calledback1conf ON elements_watching_by_txid (calledback1conf);
CREATE INDEX idx_elements_watching_by_txid_callbackxconf ON elements_watching_by_txid (callbackxconf);
CREATE INDEX idx_elements_watching_by_txid_calledbackxconf ON elements_watching_by_txid (calledbackxconf);

COMMIT;

PRAGMA foreign_keys=on;
