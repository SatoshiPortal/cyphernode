/**
 * Generate a BIP-352 silent payment address with random scan/spend keys and
 * print the address + both private keys. The printed scan privkey is what
 * the verifier needs; the spend privkey would spend received silent-payment
 * UTXOs.
 *
 * Usage:
 *   node --experimental-strip-types scripts/gen-sp-address.ts [hrp]
 * hrp is "sp" (mainnet), "tsp" (testnet/signet) or "sprt" (regtest);
 * defaults to "sprt".
 *
 * Outputs KEY=VALUE pairs so callers can eval the result:
 *   eval "$(node --experimental-strip-types scripts/gen-sp-address.ts)"
 */

import { secp256k1 } from '@noble/curves/secp256k1';
import { randomBytes } from 'node:crypto';
import { encodeSpAddress } from '../src/sp/sp-address.ts';
import type { SpHrp } from '../src/types/bip352.ts';

const Point = secp256k1.Point;
const N: bigint = secp256k1.Point.Fn.ORDER;

function randScalar(): Uint8Array {
  while (true) {
    const b = randomBytes(32);
    const n = BigInt('0x' + Buffer.from(b).toString('hex'));
    if (n > 0n && n < N) return new Uint8Array(b);
  }
}

function bytesToHex(b: Uint8Array): string {
  return Array.from(b).map((x) => x.toString(16).padStart(2, '0')).join('');
}

const hrpArg = process.argv[2] ?? 'sprt';
if (hrpArg !== 'sp' && hrpArg !== 'tsp' && hrpArg !== 'sprt') {
  console.error(`HRP must be "sp", "tsp" or "sprt", got "${hrpArg}"`);
  process.exit(1);
}
const hrp: SpHrp = hrpArg;

const scanPriv  = randScalar();
const spendPriv = randScalar();

const scanPub  = Point.BASE.multiply(BigInt('0x' + bytesToHex(scanPriv))).toBytes(true);
const spendPub = Point.BASE.multiply(BigInt('0x' + bytesToHex(spendPriv))).toBytes(true);

const address = encodeSpAddress(hrp, scanPub, spendPub);

process.stdout.write(
  [
    `SP_ADDRESS=${address}`,
    `SCAN_PRIVKEY=${bytesToHex(scanPriv)}`,
    `SPEND_PRIVKEY=${bytesToHex(spendPriv)}`,
    `SCAN_PUBKEY=${bytesToHex(scanPub)}`,
    `SPEND_PUBKEY=${bytesToHex(spendPub)}`,
  ].join('\n') + '\n'
);
