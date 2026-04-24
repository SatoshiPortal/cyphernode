import * as watchDb from './watch-db.ts';
import type { SpWatch, TxInfo } from '../types/watch.ts';
import { log } from '../log.ts';

// Mirrors the standard watch callback format (build_callback in callbacks_job.sh)
// with sp_address added as the only SP-specific field.
export function buildCallbackPayload(watch: SpWatch, tx: TxInfo): Record<string, unknown> {
  const p: Record<string, unknown> = {
    id: watch.id,
    address: watch.derived_address,
    sp_address: watch.sp_address,
    txid: tx.txid,
    vout_n: watch.vout,
    sent_amount: watch.sent_amount !== null ? parseFloat(watch.sent_amount!) : null,
    confirmations: tx.confirmations,
  };
  if (tx.hash !== undefined)          p['hash']        = tx.hash;
  if (tx.timereceived !== undefined)  p['received']    = new Date(tx.timereceived * 1000).toISOString();
  if (tx.size !== undefined)          p['size']        = tx.size;
  if (tx.vsize !== undefined)         p['vsize']       = tx.vsize;
  if (tx.fee !== undefined)           p['fees']        = parseFloat(Math.abs(tx.fee).toFixed(8));
  if (tx.replaceable !== undefined)   p['replaceable'] = tx.replaceable === 'yes';
  if (tx.blockhash) {
    p['blockhash'] = tx.blockhash;
    if (tx.blocktime !== undefined)   p['blocktime']   = new Date(tx.blocktime * 1000).toISOString();
    if (tx.blockheight !== undefined) p['blockheight'] = tx.blockheight;
  }
  return p;
}

export async function fireCallback(url: string, payload: Record<string, unknown>): Promise<void> {
  log(`[sp_watch] callback POST ${url} sp_address=${payload['sp_address']} derived_address=${payload['address']} confirmations=${payload['confirmations']}`);
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) log(`[sp_watch] callback POST ${url} => ${res.status} (error)`);
  } catch (e) {
    log(`[sp_watch] callback POST ${url} failed: ${(e as Error).message}`);
  }
}

// Fire any due callbacks for watches matched on derivedAddress, then deactivate
// watches that have had all registered callbacks fired.
export async function processWatchCallbacks(derivedAddress: string, tx: TxInfo): Promise<void> {
  const watches = watchDb.getWatchesByDerivedAddress(derivedAddress);
  for (const w of watches) {
    if (tx.confirmations === 0 && !w.called0conf && w.callback0conf) {
      await fireCallback(w.callback0conf, buildCallbackPayload(w, tx));
      watchDb.markCalled0conf(w.id);
    }
    if (tx.confirmations >= 1 && !w.called1conf && w.callback1conf) {
      await fireCallback(w.callback1conf, buildCallbackPayload(w, tx));
      watchDb.markCalled1conf(w.id);
    }
    const updated = watchDb.getWatch(w.id);
    if (updated) {
      const done0 = !updated.callback0conf || updated.called0conf;
      const done1 = !updated.callback1conf || updated.called1conf;
      if (done0 && done1) {
        watchDb.deactivateWatch(updated.id);
        log(`[sp_watch] watch id=${updated.id} sp_address=${updated.sp_address} derived_address=${updated.derived_address} completed and deactivated`);
      }
    }
  }
}
