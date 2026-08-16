/** RpcClient configuration. */
export interface RpcConfig {
  url: string; // http[s]://[user:pass@]host:port
  wallet?: string;
}

// --- getaddressinfo / listdescriptors shapes ---

export interface AddressInfo {
  hdkeypath: string; // "m/84'/1'/0'/0/5"
  parent_desc: string; // "wpkh([fp/84'/1'/0']xpub.../0/*)#ck"
  pubkey?: string; // compressed hex (not emitted for P2TR)
  ischange: boolean;
}

export interface DescriptorEntry {
  desc: string;
  internal: boolean;
  active: boolean;
  timestamp: number | string;
  range?: [number, number];
  next?: number;
}

export interface ListDescriptorsResult {
  wallet_name: string;
  descriptors: DescriptorEntry[];
}

// --- listunspent shape ---

export interface ListUnspentRow {
  txid: string;
  vout: number;
  address: string;
  amount: number; // BTC as float (Core guarantees exact 8-decimal)
  scriptPubKey: string;
  confirmations: number;
  spendable: boolean;
  solvable: boolean;
  safe: boolean;
}

// --- getrawtransaction (verbosity ≥ 1) shapes ---

export interface PrevOut {
  scriptPubKey: { hex: string };
}

export interface TxVin {
  txid: string;
  vout: number;
  scriptSig: { hex: string };
  txinwitness?: string[];
  prevout?: PrevOut; // present with getrawtransaction verbosity=2
}

export interface TxVout {
  value: number;
  n: number;
  scriptPubKey: { hex: string };
}

export interface RawTxVerbose {
  txid: string;
  hash: string;
  size: number;
  vsize: number;
  vin: TxVin[];
  vout: TxVout[];
}
