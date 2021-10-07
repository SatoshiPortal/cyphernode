PRAGMA foreign_keys=off;

BEGIN TRANSACTION;

CREATE INDEX idx_watching_watching ON watching (watching);
CREATE INDEX idx_watching_imported ON watching (imported);
CREATE INDEX idx_watching_watching_by_pub32_id ON watching (watching_by_pub32_id);
CREATE INDEX idx_watching_tx_watching_id ON watching_tx (watching_id);
CREATE INDEX idx_watching_tx_tx_id ON watching_tx (tx_id);
CREATE INDEX idx_tx_confirmations ON tx (confirmations);
CREATE INDEX idx_recipient_calledback ON recipient (calledback);
CREATE INDEX idx_recipient_webhook_url ON recipient (webhook_url);
CREATE INDEX idx_recipient_tx_id ON recipient (tx_id);
CREATE INDEX idx_recipient_batcher_id ON recipient (batcher_id);
CREATE INDEX idx_watching_by_txid_watching ON watching_by_txid (watching);
CREATE INDEX idx_watching_by_txid_callback1conf ON watching_by_txid (callback1conf);
CREATE INDEX idx_watching_by_txid_calledback1conf ON watching_by_txid (calledback1conf);
CREATE INDEX idx_watching_by_txid_callbackxconf ON watching_by_txid (callbackxconf);
CREATE INDEX idx_watching_by_txid_calledbackxconf ON watching_by_txid (calledbackxconf);
CREATE INDEX idx_lninvoice_calledback ON ln_invoice (calledback);
CREATE INDEX idx_lninvoice_callback_failed ON ln_invoice (callback_failed);

COMMIT;

PRAGMA foreign_keys=on;
