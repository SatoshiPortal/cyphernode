/**
 * BIP-352 silent payments — sender-side crypto primitives.
 *
 * Scope: pure functions for the sender algorithm. Does NOT fetch keys, decode
 * addresses, or build transactions. Operates on already-signing-ready private
 * keys; for P2TR inputs that means the tweaked output privkey (callers apply
 * BIP-341's taproot_tweak_seckey before passing in).
 *
 * Algorithm summary (BIP-352 §"Sender"):
 *   1. For each eligible input, normalize scalar a_i:
 *      - P2PKH / P2SH-P2WPKH / P2WPKH: a_i = privkey
 *      - P2TR: a_i = privkey, negated if (privkey·G).y is odd
 *   2. a = Σ a_i (mod n); fail if a = 0
 *   3. A = a·G (33-byte compressed serialization used in input_hash)
 *   4. outpoint_L = lexicographically smallest 36-byte outpoint (txid_LE || vout_LE)
 *   5. input_hash = tagged_hash("BIP0352/Inputs", outpoint_L || ser33(A))
 *   6. For each recipient (grouped by B_scan):
 *        ecdh = input_hash · a · B_scan                    (point)
 *        For each spend key B_m in group, counter k (starts at 0):
 *          t_k = int(tagged_hash("BIP0352/SharedSecret", ser33(ecdh) || ser32_be(k)))
 *          P_out = B_m + t_k·G
 *          scriptPubKey = OP_1 || x_only(P_out)
 */

import { secp256k1 } from '@noble/curves/secp256k1';
import { sha256 } from '@noble/hashes/sha2';
import { concatBytes, utf8ToBytes, bytesToHex } from '@noble/hashes/utils';

import type { SpInput, SpRecipient, SenderOutputs } from '../types/bip352.ts';

const Point = secp256k1.Point;
const N: bigint = secp256k1.Point.Fn.ORDER;

// ---------- primitives ----------

/** BIP-340 style tagged hash: sha256(sha256(tag) || sha256(tag) || msg). */
export function taggedHash(tag: string, msg: Uint8Array): Uint8Array {
  const tagHash = sha256(utf8ToBytes(tag));
  return sha256(concatBytes(tagHash, tagHash, msg));
}

export function mod(x: bigint, m: bigint = N): bigint {
  const r = x % m;
  return r < 0n ? r + m : r;
}

export function bytesToBigInt(b: Uint8Array): bigint {
  // Treat as unsigned big-endian
  return b.length === 0 ? 0n : BigInt('0x' + bytesToHex(b));
}

export function bigIntToBytes32(n: bigint): Uint8Array {
  const hex = n.toString(16).padStart(64, '0');
  const out = new Uint8Array(32);
  for (let i = 0; i < 32; i++) out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  return out;
}

/** Lexicographic byte compare. */
function cmpBytes(a: Uint8Array, b: Uint8Array): number {
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) if (a[i] !== b[i]) return a[i]! - b[i]!;
  return a.length - b.length;
}

/**
 * Build a 36-byte outpoint: txid in internal (little-endian) form || vout as 4-byte little-endian uint32.
 * Accepts txid as the display-form (big-endian) hex string, e.g. what JSON-RPC and test vectors emit.
 */
export function makeOutpoint(txidDisplayHex: string, vout: number): Uint8Array {
  if (txidDisplayHex.length !== 64) {
    throw new Error(`txid must be 64 hex chars, got ${txidDisplayHex.length}`);
  }
  const out = new Uint8Array(36);
  // Reverse hex byte order: display hex is big-endian representation of the internal LE txid.
  for (let i = 0; i < 32; i++) {
    out[31 - i] = parseInt(txidDisplayHex.slice(i * 2, i * 2 + 2), 16);
  }
  // vout little-endian
  new DataView(out.buffer).setUint32(32, vout >>> 0, true);
  return out;
}

/** Pick the smallest outpoint lexicographically. */
export function smallestOutpoint(outpoints: Uint8Array[]): Uint8Array {
  if (outpoints.length === 0) throw new Error('no outpoints');
  let best = outpoints[0]!;
  for (let i = 1; i < outpoints.length; i++) {
    if (cmpBytes(outpoints[i]!, best) < 0) best = outpoints[i]!;
  }
  return best;
}

// ---------- sender algorithm ----------

/**
 * Compute the aggregate sender scalar `a` per BIP-352 §"Sender Input Processing".
 * For P2TR inputs, negates the privkey if its pubkey has odd Y.
 * Returns 0n if the sum reduces to zero (caller treats as "cannot send").
 * Throws on per-key invariant violations (wrong length, out of range).
 */
export function aggregateInputScalar(inputs: SpInput[]): bigint {
  if (inputs.length === 0) return 0n;
  let a = 0n;
  for (const inp of inputs) {
    if (inp.privateKey.length !== 32) throw new Error('privkey must be 32 bytes');
    let d = bytesToBigInt(inp.privateKey);
    if (d === 0n || d >= N) throw new Error('privkey out of range');
    if (inp.type === 'p2tr') {
      const pub = Point.BASE.multiply(d).toAffine();
      if (pub.y % 2n !== 0n) d = mod(-d);
    }
    a = mod(a + d);
  }
  return a;
}

/** Per-recipient-group cap on number of outputs (BIP-352 §"K_max"). */
export const K_MAX = 2323;

/** A = a·G, 33-byte compressed serialization. */
export function publicSum(a: bigint): Uint8Array {
  return Point.BASE.multiply(a).toBytes(true);
}

/**
 * input_hash = int(tagged_hash("BIP0352/Inputs", outpoint_L || ser33(A))).
 * Throws if the result is 0 or >= N.
 */
export function computeInputHash(outpointL: Uint8Array, A_compressed: Uint8Array): bigint {
  if (outpointL.length !== 36) throw new Error('outpoint must be 36 bytes');
  if (A_compressed.length !== 33) throw new Error('A must be 33-byte compressed');
  const h = taggedHash('BIP0352/Inputs', concatBytes(outpointL, A_compressed));
  const x = bytesToBigInt(h);
  if (x === 0n || x >= N) throw new Error('input_hash out of range');
  return x;
}

/** ECDH shared secret point: input_hash · a · B_scan, serialized compressed (33 bytes). */
export function sharedSecret(inputHash: bigint, a: bigint, scanPubKey: Uint8Array): Uint8Array {
  const Bscan = Point.fromHex(scanPubKey);
  const scalar = mod(inputHash * a);
  if (scalar === 0n) throw new Error('shared secret scalar is zero');
  return Bscan.multiply(scalar).toBytes(true);
}

/**
 * For the given ECDH shared secret and spend pubkey, compute the k-th x-only
 * output pubkey (32 bytes) to be used as a P2TR scriptPubKey payload.
 */
export function outputXOnly(ecdhShared: Uint8Array, spendPubKey: Uint8Array, k: number): Uint8Array {
  if (ecdhShared.length !== 33) throw new Error('ecdh must be 33-byte compressed');
  if (!Number.isInteger(k) || k < 0 || k > 0xffffffff) throw new Error('k out of range');
  const kBytes = new Uint8Array(4);
  new DataView(kBytes.buffer).setUint32(0, k >>> 0, false); // big-endian
  const t = bytesToBigInt(taggedHash('BIP0352/SharedSecret', concatBytes(ecdhShared, kBytes)));
  if (t === 0n || t >= N) throw new Error('t_k out of range');
  const B = Point.fromHex(spendPubKey);
  const P = B.add(Point.BASE.multiply(t));
  const x = P.toAffine().x;
  return bigIntToBytes32(x);
}

// ---------- high-level convenience ----------


/**
 * One-shot helper: given eligible inputs, ALL transaction outpoints, and
 * recipients, produce x-only output pubkeys per BIP-352 §"Sender".
 *
 * `allOutpoints` must include every vin's outpoint (eligible OR not) — BIP-352
 * says outpoint_L is the smallest outpoint "used in the transaction", which
 * includes inputs that don't contribute to `a` (e.g. NUMS-H or uncompressed).
 * Pass just the eligible inputs' outpoints if there are no ineligible ones.
 *
 * Returns an empty `outputs` array (and a = 0n) when the algorithm fails
 * per spec:
 *  - no eligible inputs
 *  - aggregate privkey sum is zero (point at infinity)
 *  - any per-scan recipient group exceeds K_max (2323)
 *
 * Outputs are deduplicated (BIP-352 reference: `list(set(outputs))`).
 */
export function deriveSenderOutputs(
  inputs: SpInput[],
  allOutpoints: Uint8Array[],
  recipients: SpRecipient[]
): SenderOutputs {
  const a = aggregateInputScalar(inputs);
  if (a === 0n) {
    return { outputs: [], a: 0n, A: new Uint8Array(), inputHash: 0n };
  }
  const A = publicSum(a);
  const outpointL = smallestOutpoint(allOutpoints);
  const inputHash = computeInputHash(outpointL, A);

  // Group recipients by B_scan so k resets per group.
  const groups = new Map<string, SpRecipient[]>();
  const order: string[] = [];
  for (const r of recipients) {
    const key = bytesToHex(r.scanPubKey);
    if (!groups.has(key)) {
      groups.set(key, []);
      order.push(key);
    }
    groups.get(key)!.push(r);
  }

  // Fail if any group exceeds K_max
  for (const g of groups.values()) {
    if (g.length > K_MAX) {
      return { outputs: [], a, A, inputHash };
    }
  }

  // Dedup by x-only output hex
  const seen = new Set<string>();
  const outputs: Uint8Array[] = [];
  for (const key of order) {
    const group = groups.get(key)!;
    const ecdh = sharedSecret(inputHash, a, group[0]!.scanPubKey);
    for (let k = 0; k < group.length; k++) {
      const x = outputXOnly(ecdh, group[k]!.spendPubKey, k);
      const h = bytesToHex(x);
      if (!seen.has(h)) {
        seen.add(h);
        outputs.push(x);
      }
    }
  }

  return { outputs, a, A, inputHash };
}
