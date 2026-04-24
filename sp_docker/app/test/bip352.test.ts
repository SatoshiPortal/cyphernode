/**
 * Validate the BIP-352 sender crypto against the upstream test vectors
 * (bip-0352/send_and_receive_test_vectors.json). We only exercise the
 * "sending" side here.
 *
 * Skipped cases: "Receiving with labels" vectors — labels are a receiver-side
 * concept that the sender PoC doesn't touch. The sending tests for label
 * vectors still work with the standard algorithm; we run them.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { secp256k1 } from '@noble/curves/secp256k1';
import {
  aggregateInputScalar,
  publicSum,
  computeInputHash,
  sharedSecret,
  outputXOnly,
  makeOutpoint,
  smallestOutpoint,
  mod,
  bytesToBigInt,
  bigIntToBytes32,
} from '../src/sp/bip352.ts';
import type { SpInput } from '../src/types/bip352.ts';
import { detectInputType } from '../src/sp/script-type.ts';
import { decodeSpAddress } from '../src/sp/sp-address.ts';

const Point = secp256k1.Point;

const __dirname = dirname(fileURLToPath(import.meta.url));
const VECTORS_PATH = join(__dirname, 'fixtures', 'bip352_test_vectors.json');

// ---------- fixture types ----------

interface Vin {
  txid: string;
  vout: number;
  scriptSig: string;
  txinwitness: string;
  prevout: { scriptPubKey: { hex: string } };
  private_key: string;
}
interface Recipient {
  address: string;
  scan_pub_key: string;
  spend_pub_key: string;
  count?: number;
}
interface SendingCase {
  given: { vin: Vin[]; recipients: Recipient[] };
  expected: {
    outputs: string[][];
    shared_secrets: string[];
    input_private_key_sum: string;
    input_pub_keys: string[];
  };
}
interface Vector {
  comment: string;
  sending: SendingCase[];
  receiving?: unknown;
}

const vectors: Vector[] = JSON.parse(readFileSync(VECTORS_PATH, 'utf8'));

// ---------- helpers ----------

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

/** Run the full sender algorithm for one case; returns flattened outputs + diagnostics. */
function runSending(c: SendingCase): {
  outputs: Set<string>;
  inputPrivKeySumHex: string;
  inputPubKeysHex: string[];
  sharedSecretsHex: string[];
  failed: boolean;
} {
  const inputs: (SpInput & { outpoint: Uint8Array })[] = [];
  const inputPubKeysHex: string[] = [];
  const allOutpoints: Uint8Array[] = [];
  for (const v of c.given.vin) {
    allOutpoints.push(makeOutpoint(v.txid, v.vout));
    const type = detectInputType(v.prevout.scriptPubKey.hex, v.scriptSig, v.txinwitness);
    if (type === null) continue;
    const priv = hexToBytes(v.private_key);
    inputs.push({ privateKey: priv, type, outpoint: makeOutpoint(v.txid, v.vout) });

    let d = bytesToBigInt(priv);
    if (type === 'p2tr') {
      const Pt = Point.BASE.multiply(d).toAffine();
      if (Pt.y % 2n !== 0n) d = mod(-d);
    }
    inputPubKeysHex.push(bytesToHex(Point.BASE.multiply(d).toBytes(true)));
  }

  const recipientsExpanded: Recipient[] = [];
  for (const r of c.given.recipients) {
    const n = r.count ?? 1;
    for (let j = 0; j < n; j++) recipientsExpanded.push(r);
  }

  const a = aggregateInputScalar(inputs);
  if (a === 0n) {
    return {
      outputs: new Set(),
      inputPrivKeySumHex: '00'.repeat(32),
      inputPubKeysHex,
      sharedSecretsHex: [],
      failed: true,
    };
  }
  const A = publicSum(a);
  const outpointL = smallestOutpoint(allOutpoints);
  const inputHash = computeInputHash(outpointL, A);

  const groups = new Map<string, Recipient[]>();
  const order: string[] = [];
  for (const r of recipientsExpanded) {
    if (!groups.has(r.scan_pub_key)) {
      groups.set(r.scan_pub_key, []);
      order.push(r.scan_pub_key);
    }
    groups.get(r.scan_pub_key)!.push(r);
  }
  const K_MAX = 2323;
  for (const g of groups.values()) {
    if (g.length > K_MAX) {
      return {
        outputs: new Set(),
        inputPrivKeySumHex: bytesToHex(bigIntToBytes32(a)),
        inputPubKeysHex,
        sharedSecretsHex: [],
        failed: true,
      };
    }
  }

  const groupEcdh = new Map<string, Uint8Array>();
  for (const scanHex of order) {
    groupEcdh.set(scanHex, sharedSecret(inputHash, a, hexToBytes(scanHex)));
  }
  const sharedSecretsHex = recipientsExpanded.map((r) => bytesToHex(groupEcdh.get(r.scan_pub_key)!));

  const outputs = new Set<string>();
  for (const scanHex of order) {
    const group = groups.get(scanHex)!;
    const ecdh = groupEcdh.get(scanHex)!;
    for (let k = 0; k < group.length; k++) {
      const x = outputXOnly(ecdh, hexToBytes(group[k]!.spend_pub_key), k);
      outputs.add(bytesToHex(x));
    }
  }

  return {
    outputs,
    inputPrivKeySumHex: bytesToHex(bigIntToBytes32(a)),
    inputPubKeysHex,
    sharedSecretsHex,
    failed: false,
  };
}

// ---------- tests ----------

describe('BIP-352 sender — upstream test vectors', () => {
  for (const v of vectors) {
    describe(v.comment, () => {
      v.sending.forEach((c, idx) => {
        it(`sending[${idx}]`, () => {
          const got = runSending(c);

          assert.deepStrictEqual(
            [...got.inputPubKeysHex].sort(),
            [...c.expected.input_pub_keys].sort(),
            'input pubkeys'
          );

          if (got.failed || got.outputs.size === 0) {
            const anyEmpty = c.expected.outputs.some((lst) => lst.length === 0);
            assert.ok(
              anyEmpty,
              `sender produced no outputs but expected.outputs has no empty candidate set`
            );
            return;
          }

          if (c.expected.input_private_key_sum) {
            assert.equal(got.inputPrivKeySumHex, c.expected.input_private_key_sum, 'privkey sum');
          }

          const matches = c.expected.outputs.some((cand) => {
            if (cand.length !== got.outputs.size) return false;
            const s = new Set(cand);
            for (const x of got.outputs) if (!s.has(x)) return false;
            return true;
          });
          assert.ok(
            matches,
            `outputs (${[...got.outputs].sort().join(',')}) did not match any of ` +
              `${c.expected.outputs.length} candidate set(s)`
          );

          const expectedSS = c.expected.shared_secrets.filter((s) => s !== null);
          if (expectedSS.length === got.sharedSecretsHex.length) {
            assert.deepStrictEqual(got.sharedSecretsHex, expectedSS, 'shared secrets');
          }
        });
      });
    });
  }
});

describe('SP address codec', () => {
  it('decodes a BIP-352 test-vector address', () => {
    const addr = vectors[0]!.sending[0]!.given.recipients[0]!.address;
    const d = decodeSpAddress(addr);
    assert.equal(d.hrp, 'sp');
    assert.equal(d.version, 0);
    assert.equal(
      bytesToHex(d.scanPubKey),
      vectors[0]!.sending[0]!.given.recipients[0]!.scan_pub_key
    );
    assert.equal(
      bytesToHex(d.spendPubKey),
      vectors[0]!.sending[0]!.given.recipients[0]!.spend_pub_key
    );
  });
});
