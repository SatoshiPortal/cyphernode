export type SpInputType = 'p2pkh' | 'p2sh-p2wpkh' | 'p2wpkh' | 'p2tr';

/**
 * Per-input signing-ready privkey + script type. For P2TR, callers MUST pass
 * the post-BIP-341-tweak privkey; BIP-352 then applies its own even-Y negation.
 */
export interface SpInput {
  privateKey: Uint8Array; // 32 bytes
  type: SpInputType;
}

/** Recipient silent payment keys (both 33-byte compressed). */
export interface SpRecipient {
  scanPubKey: Uint8Array;
  spendPubKey: Uint8Array;
}

export interface SenderOutputs {
  /** 32-byte x-only output pubkeys, one per (recipient × k). */
  outputs: Uint8Array[];
  /** The aggregate scalar `a` (useful for debugging / verifier reuse). */
  a: bigint;
  /** A = a·G in 33-byte compressed form (for verifier reuse). */
  A: Uint8Array;
  /** input_hash scalar (for debugging). */
  inputHash: bigint;
}

/** BIP-352 silent payment address HRPs: mainnet / testnet+signet / regtest. */
export type SpHrp = 'sp' | 'tsp' | 'sprt';

/**
 * Decoded BIP-352 silent payment address.
 * HRP is 'sp' (mainnet), 'tsp' (testnet / signet), or 'sprt' (regtest).
 */
export interface SpDecoded {
  hrp: SpHrp;
  version: number; // 0 for BIP-352 v0
  scanPubKey: Uint8Array; // 33 bytes
  spendPubKey: Uint8Array; // 33 bytes
}
