export interface SendSpParams {
  address: string;
  amount: string;
  feeRate: number;   // sat/vB — always provided by the proxy layer
  wallet?: string;   // optional; falls back to no wallet context if omitted
  network: string;   // 'mainnet' | 'testnet' | 'signet' | 'regtest'
  rpcUrl: string;    // http://user:pass@host:port
  // Called with the derived P2TR address after derivation but before broadcast.
  // Use this to register watches before the tx hits the mempool.
  onDerived?: (derivedAddress: string) => Promise<void>;
}

export interface SendSpResult {
  txid: string;
  derived_address: string;
  sp_address: string;
  vout: number;
  amount: string;    // BTC formatted string e.g. "0.00100000"
  script_pubkey: string;
  hash: string;
  size: number;
  vsize: number;
  fees: string;   // BTC formatted string e.g. "0.00004112"
  raw_tx: string;
}
