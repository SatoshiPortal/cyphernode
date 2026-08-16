/**
 * Classify a prevout (scriptPubKey + scriptSig + witness) into an
 * eligible BIP-352 input type, or return null if ineligible.
 *
 * BIP-352 eligibility rules:
 *  - P2PKH: pubkey revealed by scriptSig must be compressed (33B, 02/03
 *    prefix) AND hash160 to the scriptPubKey's HASH160. For "malleated"
 *    scriptSigs with extra pushes, we take the last push that satisfies both.
 *  - P2WPKH: witness has exactly [sig, pubkey] with pubkey compressed.
 *  - P2SH-P2WPKH: scriptSig is exactly a push of redeemScript `0014<20>`
 *    and the witness is P2WPKH-shaped with a compressed pubkey.
 *  - P2TR: keypath spend is eligible. Script-path spend is eligible UNLESS
 *    the control block's internal key equals the BIP-341 NUMS point H.
 *    Stack shape respects BIP-341 annex (last element starting with 0x50,
 *    with stack length ≥ 2, is treated as annex and stripped).
 *
 * This is the minimum the real PoC needs to refuse unspendable-by-recipient
 * sends. Bitcoin Core's default descriptor wallet only produces standard
 * compressed-key / keypath-only variants, so most of these edge cases
 * matter only for "someone sends a weird UTXO to our wallet" resilience.
 */

import { ripemd160 } from '@noble/hashes/legacy';
import { sha256 } from '@noble/hashes/sha2';

import type { SpInputType } from '../types/bip352.ts';

// --- BIP-341 NUMS point H x-coordinate (BIP-340 x-only form) ---
const NUMS_H_X_HEX = '50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0';

// --- helpers ---
function hexToBytes(h: string): Uint8Array {
  const out = new Uint8Array(h.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(h.slice(i * 2, i * 2 + 2), 16);
  return out;
}
function bytesToHex(b: Uint8Array): string {
  let s = '';
  for (const x of b) s += x.toString(16).padStart(2, '0');
  return s;
}
function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
  return true;
}
function hash160(b: Uint8Array): Uint8Array {
  return ripemd160(sha256(b));
}
function isCompressedPubKey(b: Uint8Array): boolean {
  return b.length === 33 && (b[0] === 0x02 || b[0] === 0x03);
}

const NUMS_H_X = hexToBytes(NUMS_H_X_HEX);

/** Parse a Bitcoin script into its push payloads, ignoring opcodes. */
function parseScriptPushes(hex: string): Uint8Array[] | null {
  if (hex === '') return [];
  const bytes = hexToBytes(hex);
  const pushes: Uint8Array[] = [];
  let i = 0;
  while (i < bytes.length) {
    const op = bytes[i]!;
    i++;
    let len: number;
    if (op >= 0x01 && op <= 0x4b) {
      len = op;
    } else if (op === 0x4c) {
      if (i + 1 > bytes.length) return null;
      len = bytes[i]!;
      i += 1;
    } else if (op === 0x4d) {
      if (i + 2 > bytes.length) return null;
      len = bytes[i]! | (bytes[i + 1]! << 8);
      i += 2;
    } else if (op === 0x4e) {
      if (i + 4 > bytes.length) return null;
      len =
        bytes[i]! |
        (bytes[i + 1]! << 8) |
        (bytes[i + 2]! << 16) |
        (bytes[i + 3]! << 24);
      i += 4;
    } else {
      // non-push op — skip (only relevant for malleated scriptSigs in theory)
      continue;
    }
    if (i + len > bytes.length) return null;
    pushes.push(bytes.slice(i, i + len));
    i += len;
  }
  return pushes;
}

/** Parse a witness stack serialized as `varint_count (varint_len data)*`. */
function parseWitness(hex: string): Uint8Array[] | null {
  if (hex === '') return [];
  const bytes = hexToBytes(hex);
  let i = 0;
  const readVarInt = (): number | null => {
    if (i >= bytes.length) return null;
    const first = bytes[i]!;
    i += 1;
    if (first < 0xfd) return first;
    if (first === 0xfd) {
      if (i + 2 > bytes.length) return null;
      const v = bytes[i]! | (bytes[i + 1]! << 8);
      i += 2;
      return v;
    }
    if (first === 0xfe) {
      if (i + 4 > bytes.length) return null;
      const v =
        bytes[i]! |
        (bytes[i + 1]! << 8) |
        (bytes[i + 2]! << 16) |
        (bytes[i + 3]! << 24);
      i += 4;
      return v >>> 0;
    }
    return null; // 0xff (8-byte) unsupported for witness
  };

  const count = readVarInt();
  if (count === null) return null;
  const out: Uint8Array[] = [];
  for (let e = 0; e < count; e++) {
    const len = readVarInt();
    if (len === null) return null;
    if (i + len > bytes.length) return null;
    out.push(bytes.slice(i, i + len));
    i += len;
  }
  return out;
}

export function detectInputType(
  scriptPubKeyHex: string,
  scriptSigHex: string,
  witnessHex: string
): SpInputType | null {
  const spk = scriptPubKeyHex.toLowerCase();
  const ss = scriptSigHex.toLowerCase();

  // --- P2WPKH: 0x0014<20> ---
  if (spk.length === 44 && spk.startsWith('0014')) {
    const w = parseWitness(witnessHex);
    if (w === null || w.length !== 2) return null;
    if (!isCompressedPubKey(w[1]!)) return null;
    return 'p2wpkh';
  }

  // --- P2PKH: 0x76a914<20>88ac ---
  if (spk.length === 50 && spk.startsWith('76a914') && spk.endsWith('88ac')) {
    const expectedHashHex = spk.slice(6, 46);
    const pushes = parseScriptPushes(ss);
    if (pushes === null) return null;
    // BIP-352 "malleated p2pkh": take the LAST push that is a compressed pubkey
    // AND hashes to the scriptPubKey's HASH160.
    for (let j = pushes.length - 1; j >= 0; j--) {
      const p = pushes[j]!;
      if (isCompressedPubKey(p) && bytesToHex(hash160(p)) === expectedHashHex) {
        return 'p2pkh';
      }
    }
    return null;
  }

  // --- P2SH-P2WPKH: 0xa914<20>87 ---
  if (spk.length === 46 && spk.startsWith('a914') && spk.endsWith('87')) {
    // Canonical nested-segwit scriptSig: exactly one push of the 22-byte
    // redeemScript `0014<20>`. That serializes as `16 00 14 <20>` = 23 bytes.
    if (ss.length !== 46 || !ss.startsWith('160014')) return null;
    const w = parseWitness(witnessHex);
    if (w === null || w.length !== 2) return null;
    if (!isCompressedPubKey(w[1]!)) return null;
    return 'p2sh-p2wpkh';
  }

  // --- P2TR: 0x5120<32> ---
  if (spk.length === 68 && spk.startsWith('5120')) {
    const w = parseWitness(witnessHex);
    if (w === null || w.length === 0) return null;

    // Strip optional annex (BIP-341): last element, count>=2, starts with 0x50.
    let stack = w;
    const last = w[w.length - 1]!;
    if (w.length >= 2 && last.length > 0 && last[0] === 0x50) {
      stack = w.slice(0, -1);
    }

    // Keypath spend: stack = [signature]
    if (stack.length === 1) return 'p2tr';

    // Script-path spend: control block is the last remaining element.
    // control_block = leaf_version_parity(1) || internal_pubkey(32) || path(32*n)
    const cb = stack[stack.length - 1]!;
    if (cb.length < 33 || (cb.length - 1) % 32 !== 0) return null;
    const internalX = cb.slice(1, 33);
    if (bytesEqual(internalX, NUMS_H_X)) return null;
    return 'p2tr';
  }

  return null;
}
