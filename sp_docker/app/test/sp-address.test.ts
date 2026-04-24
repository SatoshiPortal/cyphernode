import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { decodeSpAddress, encodeSpAddress } from '../src/sp/sp-address.ts';

// Helper — produce a deterministic 33-byte compressed-form key (not a valid
// curve point, but encode/decode don't validate curve membership).
function fakeKey(prefix: 0x02 | 0x03, fill: number): Uint8Array {
  const k = new Uint8Array(33);
  k[0] = prefix;
  k.fill(fill, 1);
  return k;
}

describe('encodeSpAddress / decodeSpAddress', () => {
  it('round-trips a tsp address', () => {
    const scan  = fakeKey(0x02, 0xaa);
    const spend = fakeKey(0x03, 0xbb);
    const addr = encodeSpAddress('tsp', scan, spend);
    assert.ok(addr.startsWith('tsp1'), `expected tsp1 prefix, got ${addr.slice(0, 6)}`);
    const d = decodeSpAddress(addr);
    assert.equal(d.hrp, 'tsp');
    assert.equal(d.version, 0);
    assert.deepEqual(d.scanPubKey, scan);
    assert.deepEqual(d.spendPubKey, spend);
  });

  it('round-trips a sp address', () => {
    const scan  = fakeKey(0x02, 0x11);
    const spend = fakeKey(0x03, 0x22);
    const addr = encodeSpAddress('sp', scan, spend);
    assert.ok(addr.startsWith('sp1'), `expected sp1 prefix, got ${addr.slice(0, 5)}`);
    const d = decodeSpAddress(addr);
    assert.equal(d.hrp, 'sp');
    assert.deepEqual(d.scanPubKey, scan);
    assert.deepEqual(d.spendPubKey, spend);
  });

  it('different keys produce different addresses', () => {
    const a = encodeSpAddress('tsp', fakeKey(0x02, 0x01), fakeKey(0x03, 0x02));
    const b = encodeSpAddress('tsp', fakeKey(0x02, 0x03), fakeKey(0x03, 0x04));
    assert.notEqual(a, b);
  });

  it('sp and tsp produce different addresses for same keys', () => {
    const scan  = fakeKey(0x02, 0x55);
    const spend = fakeKey(0x03, 0x66);
    assert.notEqual(encodeSpAddress('sp', scan, spend), encodeSpAddress('tsp', scan, spend));
  });

  it('rejects a scan key that is not 33 bytes', () => {
    assert.throws(
      () => encodeSpAddress('tsp', new Uint8Array(32), fakeKey(0x03, 0x01)),
      /33-byte/
    );
  });

  it('rejects a spend key that is not 33 bytes', () => {
    assert.throws(
      () => encodeSpAddress('tsp', fakeKey(0x02, 0x01), new Uint8Array(34)),
      /33-byte/
    );
  });

  it('rejects a completely garbled string', () => {
    assert.throws(() => decodeSpAddress('not-an-address'), /invalid BIP-352/);
  });

  it('rejects an address with wrong HRP (bc P2TR address)', () => {
    // Valid bech32m but HRP is 'bc', not 'sp'/'tsp'.
    const p2tr = 'bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0';
    assert.throws(() => decodeSpAddress(p2tr), /unexpected HRP/);
  });

  it('rejects an empty string', () => {
    assert.throws(() => decodeSpAddress(''), /invalid BIP-352/);
  });
});
