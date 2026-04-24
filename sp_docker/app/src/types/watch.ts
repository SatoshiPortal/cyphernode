export interface SpWatch {
  id: number;
  sp_address: string;
  derived_address: string | null;
  txid: string | null;
  vout: number | null;
  sent_amount: string | null;
  callback0conf: string | null;
  callback1conf: string | null;
  called0conf: number;
  called1conf: number;
  active: number;
  inserted_ts: number;
}

// Subset of transaction fields used to build a watch callback payload.
// Mirrors what gettransaction and the walletnotify message provide.
export interface TxInfo {
  txid: string;
  hash?: string;
  confirmations: number;
  timereceived?: number;
  fee?: number;            // negative for sends in gettransaction output
  replaceable?: string;    // bip125-replaceable: "yes" | "no" | "unknown"
  blockhash?: string;
  blockheight?: number;
  blocktime?: number;
  size?: number;
  vsize?: number;
}

export interface SpSend {
  txid: string;
  sp_address: string;
  derived_address: string;
  vout: number;
  sent_amount: string;
}
