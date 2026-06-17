import { type IncomingMessage, type ServerResponse } from 'node:http';
import { decodeSpAddress } from '../sp/sp-address.ts';
import { sendSilentPayment } from '../sp/send-sp.ts';
import { RpcClient, rpcConfigFromEnv } from '../sp/rpc.ts';
import * as watchDb from '../watch/watch-db.ts';
import { parseBody, reply, replyError } from './http.ts';
import { processWatchCallbacks } from '../watch/watch-callbacks.ts';
import { reconcileWatch } from '../watch/watch-sweep.ts';
import type { SpWatch, TxInfo } from '../types/watch.ts';
import { log } from '../log.ts';

const NETWORK = process.env.SP_NETWORK ?? 'regtest';
const RPC_CFG = (() => { try { return rpcConfigFromEnv(); } catch { return null; } })();

function toHex(b: Uint8Array): string {
  return Array.from(b).map((x) => x.toString(16).padStart(2, '0')).join('');
}

// Checks the current confirmation state of a watch's txid via RPC and fires
// any already-due callbacks. Used for watch-after-spend registrations.
async function checkAndFireFromRpc(watch: SpWatch): Promise<void> {
  if (!RPC_CFG || !watch.txid || !watch.derived_address) return;
  try {
    await reconcileWatch(new RpcClient(RPC_CFG), watch);
  } catch (e) {
    // tx not yet known to wallet or RPC unavailable — notify_tx (or the periodic
    // sweep) will handle it later.
    log(`[sp_watch] RPC check for ${watch.txid} skipped: ${(e as Error).message}`);
  }
}

export async function handleValidateSpAddress(req: IncomingMessage, res: ServerResponse): Promise<void> {
  const body = await parseBody(req, res);
  if (!body) return;

  const spAddress = body['address'];
  if (typeof spAddress !== 'string') {
    return reply(res, 200, { result: { isvalid: false }, error: null, id: null });
  }

  const network = typeof body['network'] === 'string' ? body['network'] : NETWORK;
  try {
    const decoded = decodeSpAddress(spAddress);
    reply(res, 200, {
      result: {
        isvalid: true,
        address: spAddress,
        network,
        hrp: decoded.hrp,
        scan_pubkey: toHex(decoded.scanPubKey),
        spend_pubkey: toHex(decoded.spendPubKey),
      },
      error: null,
      id: null,
    });
  } catch (e) {
    reply(res, 200, { result: { isvalid: false }, error: null, id: null });
  }
}

export async function handleSend(req: IncomingMessage, res: ServerResponse): Promise<void> {
  const body = await parseBody(req, res);
  if (!body) return;

  const spAddress = body['address'];
  const amountBtc = body['amount'];
  const feeRate   = body['fee_rate'];

  if (typeof spAddress !== 'string') return replyError(res, 400, 'MISSING_SP_ADDRESS', 'address required');
  if (typeof amountBtc !== 'string') return replyError(res, 400, 'MISSING_AMOUNT', 'amount required (string)');
  if (typeof feeRate !== 'number')   return replyError(res, 400, 'MISSING_FEE_RATE', 'fee_rate required (number, sat/vB)');
  if (!RPC_CFG)                      return replyError(res, 500, 'RPC_NOT_CONFIGURED', 'BITCOIN_RPC_URL not configured');

  const network = typeof body['network'] === 'string' ? body['network'] : NETWORK;
  const wallet  = typeof body['wallet']  === 'string' ? body['wallet']  : RPC_CFG.wallet;

  log(`[send_sp] send initiated sp_address=${spAddress} amount=${amountBtc} feeRate=${feeRate} network=${network}`);

  // Tracks the derived address activated pre-broadcast so we can roll it back if
  // the send fails before the tx is broadcast (see revertPendingActivation).
  let activatedDerivedAddress: string | undefined;

  let result;
  try {
    result = await sendSilentPayment({
      address: spAddress,
      amount: amountBtc,
      feeRate,
      wallet,
      network,
      rpcUrl: RPC_CFG.url,
      onDerived: async (derivedAddress) => {
        activatedDerivedAddress = derivedAddress;
        const n = watchDb.activatePendingWatches(spAddress, derivedAddress);
        if (n > 0) log(`[send_sp] activated ${n} pending watch(es) sp_address=${spAddress} derived_address=${derivedAddress}`);
      },
    });
  } catch (e) {
    // sendSilentPayment only throws for pre-broadcast failures (it never throws
    // once a txid exists), so the payment did not happen — safe to report as a
    // failure and roll back any pending-watch activation.
    if (activatedDerivedAddress) {
      const reverted = watchDb.revertPendingActivation(spAddress, activatedDerivedAddress);
      if (reverted > 0) log(`[send_sp] reverted ${reverted} pending watch activation(s) after pre-broadcast failure sp_address=${spAddress}`);
    }
    log(`[send_sp] failed (pre-broadcast): ${(e as Error).message}`);
    return replyError(res, 400, 'SEND_FAILED', (e as Error).message);
  }

  // Past this point the tx is broadcast (txid is valid). Bookkeeping failures
  // must NOT be reported as a send failure — the caller would have no way to
  // tell the payment already happened. Persist what we can, warn on failure,
  // and always return the txid so the caller can reconcile.
  try {
    watchDb.logSend(result.txid, result.sp_address, result.derived_address, result.vout, result.amount);
    watchDb.updateWatchSendInfo(result.derived_address, result.txid, result.vout, result.amount);
  } catch (e) {
    log(`[send_sp] WARNING: post-broadcast bookkeeping failed txid=${result.txid}: ${(e as Error).message}`);
  }

  log(`[send_sp] complete txid=${result.txid} vout=${result.vout} amount=${result.amount} derived_address=${result.derived_address} vsize=${result.vsize}`);
  reply(res, 200, result);
}

export async function handleSpWatch(req: IncomingMessage, res: ServerResponse): Promise<void> {
  const body = await parseBody(req, res);
  if (!body) return;

  const spAddress = body['address'];
  if (typeof spAddress !== 'string') return replyError(res, 400, 'MISSING_SP_ADDRESS', 'address required');

  try { decodeSpAddress(spAddress); } catch (e) {
    return replyError(res, 400, 'INVALID_SP_ADDRESS', `invalid address: ${(e as Error).message}`);
  }

  const callback0conf = typeof body['callback0conf'] === 'string' ? body['callback0conf'] : undefined;
  const callback1conf = typeof body['callback1conf'] === 'string' ? body['callback1conf'] : undefined;
  const txid          = typeof body['txid']          === 'string' ? body['txid']          : undefined;

  if (txid) {
    const send = watchDb.getSendByTxid(txid);
    if (!send) return replyError(res, 404, 'TXID_NOT_FOUND', `txid ${txid} not found in sends log`);

    const id = watchDb.createActiveWatch(
      spAddress, send.derived_address, txid, send.vout, send.sent_amount,
      callback0conf, callback1conf,
    );
    const watch = watchDb.getWatch(id)!;
    log(`[sp_watch] watch id=${id} created status=active sp_address=${spAddress} derived_address=${send.derived_address} txid=${txid}`);
    await checkAndFireFromRpc(watch);
    return reply(res, 200, { address: spAddress, derived_address: send.derived_address, status: 'active' });
  }

  const id = watchDb.createWatch(spAddress, callback0conf, callback1conf);
  log(`[sp_watch] watch id=${id} created status=pending sp_address=${spAddress}`);
  reply(res, 200, { address: spAddress, status: 'pending' });
}

export async function handleSpUnwatch(req: IncomingMessage, res: ServerResponse): Promise<void> {
  const body = await parseBody(req, res);
  if (!body) return;

  const address       = body['address'];
  const callback0conf = typeof body['callback0conf'] === 'string' ? body['callback0conf'] : undefined;
  const callback1conf = typeof body['callback1conf'] === 'string' ? body['callback1conf'] : undefined;

  if (typeof address !== 'string') return replyError(res, 400, 'MISSING_SP_ADDRESS', 'address required');
  if (!callback0conf && !callback1conf) return replyError(res, 400, 'MISSING_CALLBACK', 'at least one of callback0conf or callback1conf is required');

  const n = watchDb.deactivateWatchesBySpAddress(address, callback0conf, callback1conf);
  if (n === 0) return replyError(res, 404, 'WATCH_NOT_FOUND', `no active watches found for address ${address} with the provided callback URL(s)`);
  log(`[sp_watch] deactivated ${n} watch(es) sp_address=${address}`);
  reply(res, 200, { ok: true, address, deactivated: n });
}

export function handleGetSpWatches(_req: IncomingMessage, res: ServerResponse): void {
  reply(res, 200, { watches: watchDb.listActiveWatches() });
}

export async function handleNotifyTx(req: IncomingMessage, res: ServerResponse): Promise<void> {
  const body = await parseBody(req, res);
  if (!body) return;

  if (typeof body['data'] !== 'string') {
    return replyError(res, 400, 'MISSING_DATA', 'data (base64 walletnotify message) required');
  }

  let msg: Record<string, unknown>;
  try {
    msg = JSON.parse(Buffer.from(body['data'] as string, 'base64').toString('utf8'));
  } catch {
    return replyError(res, 400, 'INVALID_DATA', 'could not decode/parse data');
  }

  const txid = msg['txid'] as string | undefined;
  if (!txid) return reply(res, 200, { ok: true, processed: 0 });

  log(`[notify_tx] txid=${txid} confirmations=${(msg['confirmations'] as number | undefined) ?? 0}`);

  const decoded = msg['decoded'] as Record<string, unknown> | undefined;
  const tx: TxInfo = {
    txid,
    hash: (decoded?.['hash'] ?? msg['hash']) as string | undefined,
    confirmations: (msg['confirmations'] as number | undefined) ?? 0,
    timereceived: msg['timereceived'] as number | undefined,
    fee: msg['fee'] as number | undefined,
    replaceable: msg['bip125-replaceable'] as string | undefined,
    blockhash: msg['blockhash'] as string | undefined,
    blockheight: msg['blockheight'] as number | undefined,
    blocktime: msg['blocktime'] as number | undefined,
    size: decoded?.['size'] as number | undefined,
    vsize: decoded?.['vsize'] as number | undefined,
  };

  const vouts = (decoded?.['vout'] as Array<Record<string, unknown>> | undefined) ?? [];
  let processed = 0;
  for (const vout of vouts) {
    const addr = (vout['scriptPubKey'] as Record<string, unknown> | undefined)?.['address'] as string | undefined;
    if (!addr) continue;
    const watches = watchDb.getWatchesByDerivedAddress(addr);
    if (watches.length > 0) {
      log(`[notify_tx] txid=${txid} matched derived_address=${addr} watches=${watches.length}`);
      await processWatchCallbacks(addr, tx);
      processed += watches.length;
    }
  }

  if (processed > 0) log(`[notify_tx] txid=${txid} total processed=${processed} watch(es)`);
  reply(res, 200, { ok: true, processed });
}
