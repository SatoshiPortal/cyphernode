/**
 * BIP-352 silent payment address encoding/decoding.
 *
 * An SP address is bech32m-encoded with HRP "sp" (mainnet), "tsp"
 * (testnet / signet) or "sprt" (regtest). The witness version nibble is 0 (encoded
 * as a 5-bit value 0 prepended), and the payload is 66 bytes:
 *   B_scan (33 bytes, compressed) || B_spend (33 bytes, compressed)
 *
 * Note: the bech32 library we use encodes the data as 5-bit groups; we
 * convert 8→5 bits after the leading version.
 */

import { bech32m } from 'bech32';
import type { SpDecoded, SpHrp } from '../types/bip352.ts';
export type { SpDecoded };

const SP_HRPS: readonly SpHrp[] = ['sp', 'tsp', 'sprt'];

// Hex helpers (keep this module dependency-light)
function hexToBytes(h: string): Uint8Array {
  if (h.length % 2 !== 0) throw new Error('odd hex length');
  const out = new Uint8Array(h.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(h.slice(i * 2, i * 2 + 2), 16);
  return out;
}

// --- 8<->5 bit conversion (copy of BIP-173 reference) ---
function convertBits(data: number[], from: number, to: number, pad: boolean): number[] {
  let acc = 0;
  let bits = 0;
  const ret: number[] = [];
  const maxv = (1 << to) - 1;
  for (const value of data) {
    if (value < 0 || value >> from !== 0) throw new Error('convertBits: invalid value');
    acc = (acc << from) | value;
    bits += from;
    while (bits >= to) {
      bits -= to;
      ret.push((acc >> bits) & maxv);
    }
  }
  if (pad) {
    if (bits > 0) ret.push((acc << (to - bits)) & maxv);
  } else if (bits >= from || ((acc << (to - bits)) & maxv) !== 0) {
    throw new Error('convertBits: invalid padding');
  }
  return ret;
}

export function decodeSpAddress(addr: string): SpDecoded {
  // bech32m encode limit is normally 90 chars — SP addresses with one spend key
  // are 117 chars, so we pass an explicit limit.
  let decoded: ReturnType<typeof bech32m.decode>;
  try {
    decoded = bech32m.decode(addr, 1023);
  } catch {
    throw new Error(`invalid BIP-352 silent payment address`);
  }
  if (!SP_HRPS.includes(decoded.prefix as SpHrp)) {
    throw new Error(`unexpected HRP: ${decoded.prefix}`);
  }
  const hrp = decoded.prefix as SpHrp;
  if (decoded.words.length < 1) throw new Error('empty SP data');
  const version = decoded.words[0]!;
  if (version !== 0) throw new Error(`unsupported SP version: ${version}`);
  const payload = Uint8Array.from(
    convertBits(Array.from(decoded.words.slice(1)), 5, 8, false)
  );
  if (payload.length !== 66) {
    throw new Error(`SP payload must be 66 bytes, got ${payload.length}`);
  }
  return {
    hrp,
    version,
    scanPubKey: payload.slice(0, 33),
    spendPubKey: payload.slice(33, 66),
  };
}

export function encodeSpAddress(
  hrp: SpHrp,
  scanPubKey: Uint8Array,
  spendPubKey: Uint8Array,
  version = 0
): string {
  if (scanPubKey.length !== 33 || spendPubKey.length !== 33) {
    throw new Error('both keys must be 33-byte compressed');
  }
  const payload = new Uint8Array(66);
  payload.set(scanPubKey, 0);
  payload.set(spendPubKey, 33);
  const words = [version, ...convertBits(Array.from(payload), 8, 5, true)];
  return bech32m.encode(hrp, words, 1023);
}

export { hexToBytes };
