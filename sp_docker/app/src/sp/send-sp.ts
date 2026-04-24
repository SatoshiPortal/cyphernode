/**
 * send-sp.ts — send a transaction to a BIP-352 silent payment address from a
 * Bitcoin Core descriptor wallet.
 *
 * Exports sendSilentPayment() for use by server.ts.
 * CLI entry point at the bottom is kept for manual testing.
 */

import { decodeSpAddress } from './sp-address.ts';
import { RpcClient } from './rpc.ts';
import { loadDescriptors, extractKeyForAddress } from './keys.ts';
import { deriveSenderOutputs, makeOutpoint } from './bip352.ts';
import type { SpInput, SpInputType } from '../types/bip352.ts';
import type { ExtractedKey } from '../types/keys.ts';
import type { ListUnspentRow, RawTxVerbose } from '../types/rpc.ts';
import type { SendSpParams, SendSpResult } from '../types/send.ts';
export type { SendSpParams, SendSpResult };

const SATS_PER_BTC = 100_000_000n;

// ---------- network ----------

function bech32PrefixForNetwork(network: string): string {
  switch (network) {
    case 'mainnet': return 'bc';
    case 'testnet':
    case 'signet':  return 'tb';
    case 'regtest': return 'bcrt';
    default: throw new Error(`unknown SP_NETWORK: ${network}`);
  }
}

function expectedSpHrp(network: string): 'sp' | 'tsp' {
  return network === 'mainnet' ? 'sp' : 'tsp';
}

// ---------- fee estimation ----------

// Conservative per-input estimate for coin selection (P2WPKH upper bound among common types)
const INPUT_VBYTES_ESTIMATE = 68;
// 10 (segwit overhead) + 43 (P2TR SP output) + 31 (P2WPKH change)
const BASE_VBYTES = 84;

function inputVbytes(type: SpInputType): number {
  switch (type) {
    case 'p2wpkh':      return 68;
    case 'p2tr':        return 58;
    case 'p2pkh':       return 148;
    case 'p2sh-p2wpkh': return 91;
  }
}

// Used during UTXO selection before we know the actual input types.
function estimateFeeSats(numInputs: number, feeRate: number): bigint {
  return BigInt(Math.ceil((BASE_VBYTES + numInputs * INPUT_VBYTES_ESTIMATE) * feeRate));
}

// Used after key extraction when we know the exact input types.
function computeFeeSats(types: SpInputType[], feeRate: number): bigint {
  const inputVb = types.reduce((s, t) => s + inputVbytes(t), 0);
  return BigInt(Math.ceil((BASE_VBYTES + inputVb) * feeRate));
}

// ---------- helpers ----------

function btcToSats(btc: string): bigint {
  if (!/^\d+(\.\d{1,8})?$/.test(btc)) throw new Error(`bad BTC amount: ${btc}`);
  const [whole, frac = ''] = btc.split('.');
  const padded = (frac + '00000000').slice(0, 8);
  return BigInt(whole!) * SATS_PER_BTC + BigInt(padded);
}

function satsToBtc(sats: bigint): string {
  const sign = sats < 0n ? '-' : '';
  const abs = sats < 0n ? -sats : sats;
  const whole = abs / SATS_PER_BTC;
  const frac = abs % SATS_PER_BTC;
  return `${sign}${whole}.${frac.toString().padStart(8, '0')}`;
}

function toHex(b: Uint8Array): string {
  return Array.from(b).map((x) => x.toString(16).padStart(2, '0')).join('');
}

// ---------- public API ----------

export async function sendSilentPayment(params: SendSpParams): Promise<SendSpResult> {
  const { address: spAddress, amount: amountBtc, feeRate, wallet, network, rpcUrl } = params;

  const rpc = new RpcClient({ url: rpcUrl, wallet });
  const amountSats = btcToSats(amountBtc);

  // 1. Decode and validate recipient SP address
  const decoded = decodeSpAddress(spAddress);
  const expectedHrp = expectedSpHrp(network);
  if (decoded.hrp !== expectedHrp) {
    throw new Error(
      `SP address HRP '${decoded.hrp}' doesn't match network '${network}' (expected '${expectedHrp}')`
    );
  }

  // 2. Select UTXOs — conservative fee estimate during selection since we
  //    don't know input types yet (that requires an RPC round-trip per UTXO).
  const utxos = await rpc.call<ListUnspentRow[]>('listunspent');
  const selected: ListUnspentRow[] = [];
  let totalSats = 0n;
  for (const u of utxos) {
    if (!u.safe || !u.spendable || !u.solvable) continue;
    selected.push(u);
    totalSats += btcToSats(u.amount.toFixed(8));
    if (totalSats >= amountSats + estimateFeeSats(selected.length, feeRate)) break;
  }
  if (totalSats < amountSats + estimateFeeSats(selected.length, feeRate)) {
    throw new Error(
      `insufficient funds: have ${satsToBtc(totalSats)} BTC, ` +
      `need at least ${satsToBtc(amountSats)} BTC + fees`
    );
  }

  // 3. Extract signing-ready privkeys (one RPC round-trip per UTXO)
  const ctx = await loadDescriptors(rpc);
  const extracted: ExtractedKey[] = [];
  for (const u of selected) {
    extracted.push(await extractKeyForAddress(rpc, ctx, u.address));
  }

  // 4. Recompute fee with actual input types now that we know them
  const feeSats = computeFeeSats(extracted.map((e) => e.type), feeRate);
  if (totalSats < amountSats + feeSats) {
    throw new Error(
      `insufficient funds after precise fee calculation: ` +
      `have ${satsToBtc(totalSats)}, need ${satsToBtc(amountSats + feeSats)}`
    );
  }

  // 5. Compute BIP-352 output
  const spInputs: SpInput[] = extracted.map((e) => ({ privateKey: e.privateKey, type: e.type }));
  const allOutpoints = selected.map((u) => makeOutpoint(u.txid, u.vout));
  const result = deriveSenderOutputs(spInputs, allOutpoints, [
    { scanPubKey: decoded.scanPubKey, spendPubKey: decoded.spendPubKey },
  ]);
  if (result.outputs.length === 0) {
    throw new Error('BIP-352 derivation produced no outputs (a_sum=0 or K_max exceeded)');
  }
  const outputX = result.outputs[0]!;
  const outputScriptPubKeyHex = '5120' + toHex(outputX);

  // 6. Build raw tx — encode the SP output as a bech32m P2TR address so
  //    createrawtransaction can accept it directly.
  const { address: bjsAddr } = await import('bitcoinjs-lib');
  const bech32Prefix = bech32PrefixForNetwork(network);
  const recipientAddr = bjsAddr.toBech32(Buffer.from(outputX), 1, bech32Prefix);

  // Notify caller of the derived address before broadcast so watches can be
  // activated while the tx is still local (guarantees 0-conf catch).
  if (params.onDerived) await params.onDerived(recipientAddr);

  const changeSats = totalSats - amountSats - feeSats;
  const outputs: Record<string, string> = { [recipientAddr]: satsToBtc(amountSats) };
  if (changeSats > 0n) {
    const changeAddr = await rpc.call<string>('getnewaddress', ['', 'bech32']);
    outputs[changeAddr] = satsToBtc(changeSats);
  }

  const inputsParam = selected.map((u) => ({ txid: u.txid, vout: u.vout }));
  const rawHex = await rpc.call<string>('createrawtransaction', [inputsParam, outputs]);

  // 7. Sign
  const signed = await rpc.call<{ hex: string; complete: boolean; errors?: unknown[] }>(
    'signrawtransactionwithwallet',
    [rawHex]
  );
  if (!signed.complete) {
    throw new Error(`signing incomplete: ${JSON.stringify(signed.errors)}`);
  }

  // 8. Broadcast + self-verify
  const txid = await rpc.call<string>('sendrawtransaction', [signed.hex]);
  const check = await rpc.call<RawTxVerbose>('getrawtransaction', [txid, 2]);
  const match = check.vout.find((o) => o.scriptPubKey.hex === outputScriptPubKeyHex);
  if (!match) {
    throw new Error(`self-verify failed: expected output ${outputScriptPubKeyHex} not found in tx`);
  }

  return {
    txid,
    derived_address: recipientAddr,
    sp_address: spAddress,
    vout: match.n,
    amount: satsToBtc(amountSats),
    script_pubkey: match.scriptPubKey.hex,
    hash: check.hash,
    size: check.size,
    vsize: check.vsize,
    fees: satsToBtc(feeSats),
    raw_tx: signed.hex,
  };
}

// ---------- CLI entry ----------

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('usage: send-sp.ts <sp-address> <amount-btc> [fee-rate-sat-vb]');
    process.exit(2);
  }
  const [spAddress, amountBtc, feeRateStr] = args as [string, string, string | undefined];
  const feeRate = feeRateStr !== undefined ? parseFloat(feeRateStr) : 1;
  const network = process.env.SP_NETWORK ?? 'regtest';
  const rpcUrl = process.env.BITCOIN_RPC_URL;
  if (!rpcUrl) throw new Error('BITCOIN_RPC_URL is required');
  const wallet = process.env.BITCOIN_RPC_WALLET;

  const result = await sendSilentPayment({ address: spAddress, amount: amountBtc, feeRate, wallet, network, rpcUrl });

  console.log('======================================================');
  console.log(' SILENT PAYMENT SENT');
  console.log(' NOTE: sp_watch notifications are not active via CLI.');
  console.log('       Use the proxy /spend_sp endpoint for watched sends.');
  console.log('======================================================');
  console.log(` txid              : ${result.txid}`);
  console.log(` SP output vout    : ${result.vout}`);
  console.log(` SP output value   : ${result.amount} BTC`);
  console.log(` SP output scriptPK: ${result.script_pubkey}`);
  console.log(` on-chain address  : ${result.derived_address}`);
  console.log(` SP address        : ${result.sp_address}`);
  console.log(` fee               : ${result.fees} BTC`);
  console.log(` vsize             : ${result.vsize} vbytes`);
  console.log('======================================================');
}

// Only run CLI entry when executed directly, not when imported by server.ts.
const isMain = process.argv[1]?.endsWith('send-sp.ts');
if (isMain) {
  main().catch((e) => {
    console.error(e instanceof Error ? e.message : e);
    process.exit(1);
  });
}
