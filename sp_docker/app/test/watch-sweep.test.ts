import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

// Must be set before any DB/RPC module is loaded.
process.env['SP_DB_PATH'] = ':memory:';
process.env['BITCOIN_RPC_URL'] = 'http://user:pass@127.0.0.1:18443';

const watchDb = await import('../src/watch/watch-db.ts');
const { sweepActiveWatches, txInfoFromGetTransaction } = await import('../src/watch/watch-sweep.ts');
const { rpcConfigFromEnv } = await import('../src/sp/rpc.ts');

const RPC_CFG = rpcConfigFromEnv();

// ---------- helpers ----------

let seq = 0;
function nextAddr(): string { return `tb1p_sw_${++seq}`; }
function nextSp(): string   { return `tsp1_sw_${++seq}`; }
function nextTxid(): string { return String(++seq).padStart(64, '0'); }

// ---------- mock fetch (serves both RPC and callback POSTs) ----------

type FetchCall = { url: string; method?: string; body: Record<string, unknown> };
let fetchCalls: FetchCall[] = [];

// Map of txid -> gettransaction result the mock RPC should return. A txid absent
// from this map makes the RPC respond with a JSON-RPC error (unknown wallet tx).
let txResults: Record<string, Record<string, unknown>> = {};
// Status the mock returns for callback POSTs (non-RPC requests).
let nextCallbackStatus = 200;

const originalFetch = globalThis.fetch;

before(() => {
  (globalThis as Record<string, unknown>)['fetch'] = async (
    input: string | URL,
    init?: RequestInit,
  ): Promise<Response> => {
    const url  = typeof input === 'string' ? input : String(input);
    const body = JSON.parse((init?.body as string) ?? '{}') as Record<string, unknown>;
    fetchCalls.push({ url, method: body['method'] as string | undefined, body });

    // JSON-RPC request to the bitcoin node?
    if (body['method'] === 'gettransaction') {
      const txid = (body['params'] as unknown[])[0] as string;
      const result = txResults[txid];
      if (!result) {
        return new Response(
          JSON.stringify({ result: null, error: { code: -5, message: 'Invalid or non-wallet transaction id' } }),
          { status: 500 },
        );
      }
      return new Response(JSON.stringify({ result, error: null }), { status: 200 });
    }

    // Otherwise it's a watch callback POST.
    return new Response('{}', { status: nextCallbackStatus });
  };
});

after(() => {
  globalThis.fetch = originalFetch;
});

beforeEach(() => {
  fetchCalls = [];
  txResults = {};
  nextCallbackStatus = 200;
});

function callbackCalls(): FetchCall[] {
  return fetchCalls.filter((c) => c.method !== 'gettransaction');
}

// ---------- txInfoFromGetTransaction ----------

describe('txInfoFromGetTransaction', () => {
  it('maps top-level and decoded fields', () => {
    const tx = txInfoFromGetTransaction('aa'.repeat(32), {
      confirmations: 2,
      timereceived: 1_700_000_000,
      fee: -0.00001,
      'bip125-replaceable': 'no',
      blockhash: 'bb'.repeat(32),
      blockheight: 800_001,
      blocktime: 1_710_000_000,
      decoded: { hash: 'cc'.repeat(32), size: 250, vsize: 141 },
    });
    assert.equal(tx.confirmations, 2);
    assert.equal(tx.hash, 'cc'.repeat(32));
    assert.equal(tx.size, 250);
    assert.equal(tx.vsize, 141);
    assert.equal(tx.replaceable, 'no');
    assert.equal(tx.blockheight, 800_001);
  });

  it('defaults confirmations to 0 when absent', () => {
    const tx = txInfoFromGetTransaction('dd'.repeat(32), {});
    assert.equal(tx.confirmations, 0);
  });
});

// ---------- sweepActiveWatches ----------

describe('sweepActiveWatches', () => {
  it('fires a missed 1-conf callback for a confirmed watch and deactivates it', async () => {
    const sp  = nextSp();
    const der = nextAddr();
    const tx  = nextTxid();
    const cb1 = 'http://test/sweep-cb1';
    const id  = watchDb.createActiveWatch(sp, der, tx, 0, '0.01', undefined, cb1);

    // Tx is confirmed on-chain but the walletnotify for it was never delivered.
    txResults[tx] = { confirmations: 1, decoded: { size: 200, vsize: 110 } };

    const n = await sweepActiveWatches(RPC_CFG);
    assert.equal(n, 1);

    const cbs = callbackCalls();
    assert.equal(cbs.length, 1);
    assert.equal(cbs[0]!.url, cb1);
    assert.equal(cbs[0]!.body['confirmations'], 1);

    const w = watchDb.getWatch(id)!;
    assert.equal(w.called1conf, 1);
    assert.equal(w.active, 0);
  });

  it('does not re-fire callbacks already delivered (idempotent)', async () => {
    const sp  = nextSp();
    const der = nextAddr();
    const tx  = nextTxid();
    const id  = watchDb.createActiveWatch(sp, der, tx, 0, '0.01', undefined, 'http://test/sweep-once');
    watchDb.markCalled1conf(id);
    txResults[tx] = { confirmations: 3 };

    await sweepActiveWatches(RPC_CFG);
    assert.equal(callbackCalls().length, 0);
    // both callbacks resolved (cb0 absent, cb1 already called) → deactivated
    assert.equal(watchDb.getWatch(id)!.active, 0);
  });

  it('skips pending watches (no txid) — nothing to query', async () => {
    watchDb.createWatch(nextSp(), 'http://test/pending-cb0');
    const n = await sweepActiveWatches(RPC_CFG);
    assert.equal(n, 0);
    assert.equal(fetchCalls.length, 0); // no RPC, no callbacks
  });

  it('skips a watch whose tx the wallet does not know, without aborting the sweep', async () => {
    const spA = nextSp(), derA = nextAddr(), txA = nextTxid();
    const spB = nextSp(), derB = nextAddr(), txB = nextTxid();
    const idA = watchDb.createActiveWatch(spA, derA, txA, 0, '0.01', undefined, 'http://test/unknown');
    const idB = watchDb.createActiveWatch(spB, derB, txB, 0, '0.01', undefined, 'http://test/known');

    // txA missing from txResults → RPC error; txB resolves confirmed.
    txResults[txB] = { confirmations: 1 };

    const n = await sweepActiveWatches(RPC_CFG);
    assert.equal(n, 1); // only B reconciled

    assert.equal(watchDb.getWatch(idA)!.active, 1); // A untouched, still active
    assert.equal(watchDb.getWatch(idB)!.active, 0); // B completed
  });

  it('leaves the watch active when callback delivery fails, for a later retry', async () => {
    const sp  = nextSp();
    const der = nextAddr();
    const tx  = nextTxid();
    const id  = watchDb.createActiveWatch(sp, der, tx, 0, '0.01', undefined, 'http://test/sweep-fail');
    txResults[tx] = { confirmations: 1 };
    nextCallbackStatus = 503;

    await sweepActiveWatches(RPC_CFG);
    const w = watchDb.getWatch(id)!;
    assert.equal(w.called1conf, 0); // not marked → retried next sweep
    assert.equal(w.active, 1);
  });
});
