import type { SpInputType } from './bip352.ts';
import type { DescriptorEntry } from './rpc.ts';

export interface ExtractedKey {
  /** Signing-ready private key (32 bytes). For P2TR, this is the tweaked output privkey. */
  privateKey: Uint8Array;
  /** Script type for BIP-352 aggregation. */
  type: SpInputType;
  /** Pubkey derived from the privkey (33-byte compressed). Useful for sanity checks. */
  publicKey: Uint8Array;
}

export interface ExtractContext {
  /** Cache of `listdescriptors true` — one call per send. Never log this. */
  descriptors: DescriptorEntry[];
}
