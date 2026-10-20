/**
 * watch-sweep.ts — periodic safety net for missed watch notifications.
 *
 * The live path (proxy forwards walletnotify -> /notify_tx) is best-effort: if
 * the SP container is down/restarting, the MQTT subscription drops a message, or
 * the single 0-conf/1-conf walletnotify event is otherwise lost, the matching
 * callback would never fire. Unlike the main proxy, SP has no per-block sweep or
 * callbacks cron, so this interval is the recovery mechanism.
 *
 * Every tick we re-query each active, broadcast watch's tx via gettransaction and
 * re-run processWatchCallbacks. That is idempotent: callbacks already delivered
 * are flagged (called0conf/called1conf) and not re-fired, and a watch is
 * deactivated once all its callbacks are delivered.
 *
 * NOTE (multi-wallet limitation): gettransaction is wallet-scoped and the sweep
 * queries the configured default wallet only (sp_watches does not record which
 * wallet a send used). For deployments with a single spending wallet this covers
 * everything; sends from a non-default spending wallet are recovered via the live
 * walletnotify path but not by this sweep (their gettransaction returns an error
 * here, which is caught and skipped). Recording the wallet per send would close
 * that gap if it ever matters.
 */

import { RpcClient } from '../sp/rpc.ts';
import type { RpcConfig } from '../types/rpc.ts';
import type { SpWatch, TxInfo } from '../types/watch.ts';
import * as watchDb from './watch-db.ts';
import { processWatchCallbacks } from './watch-callbacks.ts';
import { log } from '../log.ts';

// Build a TxInfo from a `gettransaction txid true true` result. The verbose flag
// adds the `decoded` object (size/vsize/hash); the top-level fields carry the
// wallet's confirmation/block metadata.
export function txInfoFromGetTransaction(txid: string, raw: Record<string, unknown>): TxInfo {
  const decoded = raw['decoded'] as Record<string, unknown> | undefined;
  return {
    txid,
    hash: (raw['hash'] ?? decoded?.['hash']) as string | undefined,
    confirmations: (raw['confirmations'] as number | undefined) ?? 0,
    timereceived: raw['timereceived'] as number | undefined,
    fee: raw['fee'] as number | undefined,
    replaceable: raw['bip125-replaceable'] as string | undefined,
    blockhash: raw['blockhash'] as string | undefined,
    blockheight: raw['blockheight'] as number | undefined,
    blocktime: raw['blocktime'] as number | undefined,
    size: decoded?.['size'] as number | undefined,
    vsize: decoded?.['vsize'] as number | undefined,
  };
}

// Reconcile a single watch against the chain and fire any due callbacks. Throws
// if the RPC call fails (caller decides whether to swallow per-watch errors).
export async function reconcileWatch(rpc: RpcClient, watch: SpWatch): Promise<void> {
  if (!watch.txid || !watch.derived_address) return;
  const raw = await rpc.call<Record<string, unknown>>('gettransaction', [watch.txid, true, true]);
  const tx = txInfoFromGetTransaction(watch.txid, raw);
  await processWatchCallbacks(watch.derived_address, tx);
}

// Guard against overlapping sweeps: a slow tick (many watches / slow RPC) must
// not be re-entered by the next interval firing.
let sweeping = false;

// One pass over all active, broadcast watches. Per-watch RPC failures are logged
// and skipped so a single bad/unknown tx can't abort the whole sweep.
export async function sweepActiveWatches(rpcCfg: RpcConfig): Promise<number> {
  if (sweeping) {
    log('[sp_sweep] previous sweep still running, skipping this tick');
    return 0;
  }
  sweeping = true;
  try {
    const watches = watchDb.listActiveWatchesWithTxid();
    if (watches.length === 0) return 0;
    log(`[sp_sweep] reconciling ${watches.length} active watch(es)`);
    const rpc = new RpcClient(rpcCfg);
    let reconciled = 0;
    for (const w of watches) {
      try {
        await reconcileWatch(rpc, w);
        reconciled++;
      } catch (e) {
        log(`[sp_sweep] watch id=${w.id} txid=${w.txid} reconcile skipped: ${(e as Error).message}`);
      }
    }
    return reconciled;
  } finally {
    sweeping = false;
  }
}

// Start the periodic sweep. Returns the timer (unref'd so it never keeps the
// process alive on its own) or null when disabled (intervalMs <= 0).
export function startWatchSweep(rpcCfg: RpcConfig, intervalMs: number): ReturnType<typeof setInterval> | null {
  if (!Number.isFinite(intervalMs) || intervalMs <= 0) {
    log('[sp_sweep] disabled (interval <= 0)');
    return null;
  }
  log(`[sp_sweep] starting, interval=${intervalMs}ms`);
  const timer = setInterval(() => {
    sweepActiveWatches(rpcCfg).catch((e) => log(`[sp_sweep] sweep error: ${(e as Error).message}`));
  }, intervalMs);
  timer.unref();
  return timer;
}
