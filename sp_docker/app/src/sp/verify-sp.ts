/**
 * verify-sp.ts — receiver-side verification of a silent payment.
 *
 * Given the recipient's scan private key and spend public key, fetch the
 * referenced transaction from Bitcoin Core and re-derive the expected BIP-352
 * output using only information available to a receiver (no sender privkeys).
 * Prints whether the expected output is present in the tx.
 *
 * Usage:
 *   SCAN_PRIVKEY=<hex> SPEND_PUBKEY=<hex> \
 *   BITCOIN_RPC_URL=http://user:pass@127.0.0.1:18443 \
 *     node --experimental-strip-types src/sp/verify-sp.ts <txid>
 *
 * Receiver algorithm (BIP-352):
 *   1. For each eligible tx input, extract its pubkey (from scriptSig/
 *      witness/scriptPubKey). Negate the pubkey's parity for P2TR inputs
 *      (match the sender's negation rule).
 *   2. A = sum of input pubkeys (point addition).
 *   3. outpoint_L = smallest outpoint across ALL tx inputs.
 *   4. input_hash = tagged_hash("BIP0352/Inputs", outpoint_L || ser33(A))
 *   5. ecdh = input_hash · b_scan · A
 *   6. For k = 0, 1, …: x_expected = x_only(B_spend + H_BIP0352/SharedSecret(ecdh || k)·G)
 *      Compare to every x-only P2TR output in the tx.
 */

import { secp256k1 } from '@noble/curves/secp256k1';

import { RpcClient, rpcConfigFromEnv } from './rpc.ts';
import {
  computeInputHash,
  smallestOutpoint,
  outputXOnly,
  publicSum,
  mod,
  bytesToBigInt,
  makeOutpoint,
} from './bip352.ts';
import type { SpInputType } from '../types/bip352.ts';
import { detectInputType } from './script-type.ts';

const Point = secp256k1.Point;

// ---------- helpers ----------

function hexToBytes(h: string): Uint8Array {
  const out = new Uint8Array(h.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(h.slice(i * 2, i * 2 + 2), 16);
  return out;
}
function bytesToHex(b: Uint8Array): string {
  return Array.from(b).map((x) => x.toString(16).padStart(2, '0')).join('');
}

// ---------- tx parsing ----------

interface PrevOut {
  scriptPubKey: { hex: string };
}
interface TxVin {
  txid: string;
  vout: number;
  scriptSig: { hex: string };
  txinwitness?: string[];
  prevout?: PrevOut; // present with getrawtransaction verbosity=2
}
interface TxVout {
  value: number;
  n: number;
  scriptPubKey: { hex: string };
}
interface RawTxVerbose {
  txid: string;
  vin: TxVin[];
  vout: TxVout[];
}

/**
 * Given Core's verbose vin structure, compute the input pubkey to use for
 * BIP-352 aggregation. Returns null when the input is ineligible.
 */
function extractInputPubkey(vin: TxVin): Uint8Array | null {
  if (!vin.prevout) return null;
  const witnessHex = (vin.txinwitness ?? []).join('');
  // Reconstruct witness serialization for detectInputType: count varint + each element (len varint + data).
  const witSer = serializeWitness(vin.txinwitness ?? []);
  const type = detectInputType(vin.prevout.scriptPubKey.hex, vin.scriptSig.hex, witSer);
  if (type === null) return null;

  const pub = pubkeyFromInput(type, vin);
  if (!pub) return null;

  // BIP-352 negation for P2TR: pick the even-Y representation.
  if (type === 'p2tr') {
    // Convert x-only (32) to 33-byte compressed. We don't know the sender's
    // privkey's even-Y-negation decision a priori; BIP-352 receiver simply
    // treats the output pubkey as having even Y (P2TR convention).
    // Since the scriptPubKey is an x-only pubkey with implicit even Y,
    // we prepend 0x02.
    if (pub.length === 32) return new Uint8Array([0x02, ...pub]);
  }

  if (pub.length !== 33) return null;
  // Return as-is for non-P2TR.
  void witnessHex;
  return pub;
}

function pubkeyFromInput(type: SpInputType, vin: TxVin): Uint8Array | null {
  if (type === 'p2tr') {
    // Pubkey = x-only from scriptPubKey (bytes 2..34)
    const spk = vin.prevout!.scriptPubKey.hex;
    if (!spk.startsWith('5120') || spk.length !== 68) return null;
    return hexToBytes(spk.slice(4));
  }

  if (type === 'p2wpkh' || type === 'p2sh-p2wpkh') {
    const w = vin.txinwitness ?? [];
    if (w.length !== 2) return null;
    return hexToBytes(w[1]!);
  }

  if (type === 'p2pkh') {
    const pushes = parseScriptPushes(vin.scriptSig.hex);
    if (!pushes) return null;
    // BIP-352 "last push" rule for malleated p2pkh.
    // For standard p2pkh the pubkey is the last push.
    for (let i = pushes.length - 1; i >= 0; i--) {
      const p = pushes[i]!;
      if (p.length === 33 && (p[0] === 0x02 || p[0] === 0x03)) return p;
    }
    return null;
  }

  return null;
}

function parseScriptPushes(hex: string): Uint8Array[] | null {
  if (hex === '') return [];
  const bytes = hexToBytes(hex);
  const out: Uint8Array[] = [];
  let i = 0;
  while (i < bytes.length) {
    const op = bytes[i]!;
    i++;
    let len: number;
    if (op >= 0x01 && op <= 0x4b) len = op;
    else if (op === 0x4c) {
      len = bytes[i]!;
      i++;
    } else if (op === 0x4d) {
      len = bytes[i]! | (bytes[i + 1]! << 8);
      i += 2;
    } else if (op === 0x4e) {
      len = bytes[i]! | (bytes[i + 1]! << 8) | (bytes[i + 2]! << 16) | (bytes[i + 3]! << 24);
      i += 4;
    } else continue;
    if (i + len > bytes.length) return null;
    out.push(bytes.slice(i, i + len));
    i += len;
  }
  return out;
}

/** Serialize witness stack back to the varint-prefixed form detectInputType expects. */
function serializeWitness(elements: string[]): string {
  const parts: string[] = [];
  parts.push(toVarIntHex(elements.length));
  for (const e of elements) {
    const bytes = hexToBytes(e);
    parts.push(toVarIntHex(bytes.length));
    parts.push(e);
  }
  return parts.join('');
}

function toVarIntHex(n: number): string {
  if (n < 0xfd) return n.toString(16).padStart(2, '0');
  if (n <= 0xffff) return 'fd' + (n & 0xff).toString(16).padStart(2, '0') + ((n >> 8) & 0xff).toString(16).padStart(2, '0');
  if (n <= 0xffffffff) {
    const b = new Uint8Array(4);
    new DataView(b.buffer).setUint32(0, n >>> 0, true);
    return 'fe' + bytesToHex(b);
  }
  throw new Error('varint too large');
}

// ---------- main ----------

async function main(): Promise<void> {
  const txid = process.argv[2];
  if (!txid) {
    console.error('usage: verify-sp.ts <txid>');
    console.error('env: SCAN_PRIVKEY=<hex>  SPEND_PUBKEY=<hex>  BITCOIN_RPC_URL=...');
    process.exit(2);
  }
  const scanPrivHex = process.env.SCAN_PRIVKEY;
  const spendPubHex = process.env.SPEND_PUBKEY;
  if (!scanPrivHex || !spendPubHex) {
    throw new Error('SCAN_PRIVKEY and SPEND_PUBKEY env vars are required');
  }
  const b_scan = bytesToBigInt(hexToBytes(scanPrivHex));
  const B_spend = hexToBytes(spendPubHex);

  const rpc = new RpcClient(rpcConfigFromEnv());

  // Try verbosity 2 (includes prevout per input); fall back to 1 if prevout
  // is missing (older Core, no txindex, etc.) and fetch prevouts ourselves.
  let tx = await rpc.call<RawTxVerbose>('getrawtransaction', [txid, 2], false)
    .catch(async () => rpc.call<RawTxVerbose>('getrawtransaction', [txid, true], false));

  // If any vin is missing prevout, resolve it by fetching the parent tx.
  for (const vin of tx.vin) {
    if (!vin.prevout) {
      const parentTx = await rpc.call<RawTxVerbose>('getrawtransaction', [vin.txid, true], false);
      const out = parentTx.vout.find((o) => o.n === vin.vout);
      if (out) vin.prevout = { scriptPubKey: { hex: out.scriptPubKey.hex } };
    }
  }

  // Collect ALL outpoints (eligible + not) for outpoint_L.
  const allOutpoints = tx.vin.map((v) => makeOutpoint(v.txid, v.vout));

  // Aggregate input pubkeys for eligible inputs.
  const pubs: Uint8Array[] = [];
  for (const vin of tx.vin) {
    const p = extractInputPubkey(vin);
    if (p) pubs.push(p);
  }
  if (pubs.length === 0) throw new Error('no eligible inputs found in tx (could not resolve any input prevout)');

  // A = sum of input pubkeys as points (compressed serialization for input_hash)
  let Asum = Point.fromHex(pubs[0]!);
  for (let i = 1; i < pubs.length; i++) Asum = Asum.add(Point.fromHex(pubs[i]!));
  const Abytes = Asum.toBytes(true);

  const outpointL = smallestOutpoint(allOutpoints);
  const inputHash = computeInputHash(outpointL, Abytes);

  // ecdh = input_hash · b_scan · A  (as a point, serialized compressed)
  const ecdhPoint = Asum.multiply(mod(inputHash * b_scan));
  const ecdh = ecdhPoint.toBytes(true);

  console.log(`tx              : ${tx.txid}`);
  console.log(`eligible inputs : ${pubs.length}`);
  console.log(`A (sum pubs)    : ${bytesToHex(Abytes)}`);
  console.log(`outpoint_L      : ${bytesToHex(outpointL)}`);
  console.log(`input_hash      : ${inputHash.toString(16).padStart(64, '0')}`);
  console.log(`ecdh            : ${bytesToHex(ecdh)}`);

  // Collect all P2TR output x-only pubkeys from the tx
  const p2trOutputs = new Map<string, number>(); // x-only hex → vout index
  for (const o of tx.vout) {
    const spk = o.scriptPubKey.hex.toLowerCase();
    if (spk.length === 68 && spk.startsWith('5120')) {
      p2trOutputs.set(spk.slice(4), o.n);
    }
  }

  // Try k = 0, 1, 2, ... up to a small cap; in practice a sender won't send many
  // outputs to the same recipient, so 16 is generous for a PoC verifier.
  const K_CAP = 16;
  let foundAny = false;
  for (let k = 0; k < K_CAP; k++) {
    const x = outputXOnly(ecdh, B_spend, k);
    const xHex = bytesToHex(x);
    const vout = p2trOutputs.get(xHex);
    if (vout !== undefined) {
      console.log(`MATCH k=${k}: output #${vout} = ${xHex}`);
      foundAny = true;
    }
  }
  if (!foundAny) {
    console.log('No SP outputs matched for this (scan_priv, spend_pub) pair.');
    process.exit(3);
  }
  publicSum; // silence unused warning if we drop it later
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
