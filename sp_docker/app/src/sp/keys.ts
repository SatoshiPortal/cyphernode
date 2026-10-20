/**
 * Extract the signing-ready private key for a Bitcoin Core UTXO via the
 * descriptor wallet, using the same chain the Phase 0 bash probe validated:
 *
 *   UTXO addr → getaddressinfo.hdkeypath + parent_desc
 *   → match to listdescriptors(true) entry (by prefix + internal flag)
 *   → BIP32-derive the leaf privkey from that xpriv + child path
 *   → (P2TR only) apply BIP-341 taproot_tweak_seckey to get the signing key
 *
 * The caller then passes this signing-ready privkey to bip352.ts, which
 * applies its own even-Y negation for P2TR.
 *
 * SECURITY: listdescriptors(true) returns extended private keys. The result
 * is cached in ExtractContext but never logged. SP_REDACT_LOGS=true (default)
 * signals callers to suppress any debug output containing descriptor data.
 */

import { HDKey, type Versions } from '@scure/bip32';
import { secp256k1 } from '@noble/curves/secp256k1';
import { sha256 } from '@noble/hashes/sha2';
import { concatBytes, utf8ToBytes } from '@noble/hashes/utils';

import type { SpInputType } from '../types/bip352.ts';
import { mod, bytesToBigInt, bigIntToBytes32 } from './bip352.ts';
import { RpcClient } from './rpc.ts';
import type { AddressInfo, ListDescriptorsResult } from '../types/rpc.ts';
import type { ExtractedKey, ExtractContext } from '../types/keys.ts';
export type { ExtractedKey, ExtractContext };

const Point = secp256k1.Point;
const N: bigint = secp256k1.Point.Fn.ORDER;

// BIP32 version bytes: @scure/bip32 defaults to mainnet (xprv/xpub).
// Regtest and testnet use tprv/tpub with different version prefixes.
const MAINNET_VERSIONS: Versions = { private: 0x0488ade4, public: 0x0488b21e };
const TESTNET_VERSIONS: Versions = { private: 0x04358394, public: 0x043587cf };

function hdVersions(xkey: string): Versions {
  if (xkey.startsWith('tprv') || xkey.startsWith('tpub')) return TESTNET_VERSIONS;
  return MAINNET_VERSIONS;
}

// --- extraction ---

/** Return the descriptor prefix (wpkh / tr / sh / pkh). */
function descriptorPrefix(d: string): string {
  const m = d.match(/^([a-z]+)\(/);
  if (!m) throw new Error(`cannot parse descriptor prefix: ${d}`);
  return m[1]!;
}

/** Map a descriptor prefix to a BIP-352 input type. */
function prefixToInputType(prefix: string, innerPrefix?: string): SpInputType {
  if (prefix === 'wpkh') return 'p2wpkh';
  if (prefix === 'tr') return 'p2tr';
  if (prefix === 'pkh') return 'p2pkh';
  if (prefix === 'sh' && innerPrefix === 'wpkh') return 'p2sh-p2wpkh';
  throw new Error(`unsupported descriptor type: ${prefix}(${innerPrefix ?? '?'})`);
}

/** Extract the inner descriptor prefix for sh(wpkh(...)). */
function innerPrefix(d: string): string | undefined {
  const m = d.match(/^[a-z]+\(([a-z]+)\(/);
  return m?.[1];
}

/**
 * Pull the xpriv out of a descriptor string. We accept either master-form
 *   "wpkh(tprv...<path>/*)"
 * or account-extended form (rare in listdescriptors output).
 */
function extractXpriv(desc: string): { xpriv: string; pathAfterKey: string } {
  // Look for tprv or xprv anywhere in the descriptor.
  const m = desc.match(/\b((?:xprv|tprv)[1-9A-HJ-NP-Za-km-z]+)(\/[0-9h'/*]*)?/);
  if (!m) throw new Error(`no xpriv in descriptor: ${desc}`);
  return { xpriv: m[1]!, pathAfterKey: m[2] ?? '' };
}

/**
 * Derive an HDKey along a derivation suffix, supporting both `'` and `h` as
 * hardened markers. Accepts a trailing `/*` which is ignored (caller provides
 * the concrete child below).
 */
function deriveHd(root: HDKey, path: string): HDKey {
  // Normalize: turn h → ', strip leading slash, drop trailing /* wildcards
  let p = path.replace(/h/g, "'").replace(/^\//, '');
  p = p.replace(/\/\*$/, '');
  if (p === '') return root;
  // @scure/bip32 accepts "m/..." or "..."
  return root.derive('m/' + p);
}

// --- BIP-341 taproot_tweak_seckey (for P2TR, BIP-86 style: no merkle root) ---

function taggedHash(tag: string, msg: Uint8Array): Uint8Array {
  const t = sha256(utf8ToBytes(tag));
  return sha256(concatBytes(t, t, msg));
}

/**
 * taproot_tweak_seckey per BIP-341, BIP-86 case (no merkle root):
 *   if internal_pub.y is odd: d = n - d
 *   t = int(tagged_hash("TapTweak", x(internal_pub)))
 *   return (d + t) mod n
 */
function taprootTweakSeckey(dInternal: Uint8Array): Uint8Array {
  let d = bytesToBigInt(dInternal);
  const Pint = Point.BASE.multiply(d);
  const aff = Pint.toAffine();
  if (aff.y % 2n !== 0n) d = mod(-d);
  const xOnly = bigIntToBytes32(aff.x);
  const t = mod(bytesToBigInt(taggedHash('TapTweak', xOnly)));
  if (t >= N) throw new Error('TapTweak scalar out of range');
  return bigIntToBytes32(mod(d + t));
}

// --- public API ---


export async function loadDescriptors(rpc: RpcClient): Promise<ExtractContext> {
  const ld = await rpc.call<ListDescriptorsResult>('listdescriptors', [true]);
  return { descriptors: ld.descriptors };
}

/**
 * Extract the signing-ready private key for a given UTXO address.
 * - Looks up hdkeypath + parent_desc via getaddressinfo.
 * - Matches that to the right xpriv descriptor in the cached listdescriptors output.
 * - BIP32-derives the leaf privkey.
 * - For P2TR, applies BIP-341 BIP-86 taproot_tweak_seckey.
 */
export async function extractKeyForAddress(
  rpc: RpcClient,
  ctx: ExtractContext,
  address: string
): Promise<ExtractedKey> {
  const info = await rpc.call<AddressInfo>('getaddressinfo', [address]);

  const parentPrefix = descriptorPrefix(info.parent_desc);
  const match = ctx.descriptors.find(
    (d) => descriptorPrefix(d.desc) === parentPrefix && d.internal === info.ischange
  );
  if (!match) {
    throw new Error(
      `no matching xpriv descriptor for ${address} (prefix=${parentPrefix}, internal=${info.ischange})`
    );
  }

  // For sh(wpkh(...)) we need to know the inner type too.
  const type = prefixToInputType(parentPrefix, innerPrefix(info.parent_desc));

  // Derive the leaf privkey from the xpriv using the hdkeypath's child path.
  const { xpriv, pathAfterKey } = extractXpriv(match.desc);
  const root = HDKey.fromExtendedKey(xpriv, hdVersions(xpriv));
  // xpriv path usually starts with `m` internally; pathAfterKey is the portion
  // after the xpriv serialization (e.g. "/84'/1'/0'/0/*").
  // The full deriver from the xpriv root to the leaf is: pathAfterKey without
  // the wildcard, then the concrete child indices at the end of hdkeypath.
  //
  // In master-key form (what Core emits), pathAfterKey has the full hardened
  // prefix like /84'/1'/0'/0/* — so just derive using hdkeypath minus the "m/"
  // is equivalent.
  const childPath = info.hdkeypath.replace(/^m\//, '');
  // Sanity check: the pathAfterKey (sans wildcard) should be a prefix of childPath.
  const pathPrefix = pathAfterKey.replace(/^\//, '').replace(/\/\*$/, '').replace(/h/g, "'");
  const normalChild = childPath.replace(/h/g, "'");
  if (pathPrefix && !normalChild.startsWith(pathPrefix)) {
    throw new Error(
      `hdkeypath (${info.hdkeypath}) doesn't extend descriptor path (${pathAfterKey})`
    );
  }
  const leaf = deriveHd(root, childPath);
  if (!leaf.privateKey) throw new Error('derived HDKey has no private key');

  let privateKey: Uint8Array = leaf.privateKey;
  if (type === 'p2tr') {
    // BIP-86: no merkle root, tweak with just the internal pubkey.
    privateKey = taprootTweakSeckey(privateKey);
  }

  // Compute pubkey (useful for sanity-check & logging).
  const publicKey = Point.BASE.multiply(bytesToBigInt(privateKey)).toBytes(true);

  // Optional cross-check: for non-P2TR, Core's getaddressinfo.pubkey should match.
  if (info.pubkey && type !== 'p2tr') {
    const gotHex = Array.from(publicKey)
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
    if (gotHex !== info.pubkey.toLowerCase()) {
      throw new Error(
        `extracted privkey pubkey mismatch for ${address}: expected ${info.pubkey}, got ${gotHex}`
      );
    }
  }

  return { privateKey, type, publicKey };
}
