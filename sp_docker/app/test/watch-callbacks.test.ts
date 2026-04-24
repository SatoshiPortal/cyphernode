import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import type { SpWatch, TxInfo } from '../src/types/watch.ts';

// Must be set before any DB module is loaded.
process.env['SP_DB_PATH'] = ':memory:';

const watchDb = await import('../src/watch/watch-db.ts');
const { buildCallbackPayload, processWatchCallbacks } = await import('../src/watch/watch-callbacks.ts');

// ---------- helpers ----------

let seq = 0;
function nextAddr(): string { return `tb1p_cb_${++seq}`; }
function nextSp(): string   { return `tsp1_cb_${++seq}`; }
function nextTxid(): string { return String(++seq).padStart(64, '0'); }

function makeTx(overrides: Partial<TxInfo> = {}): TxInfo {
  return {
    txid: nextTxid(),
    confirmations: 0,
    ...overrides,
  };
}

function makeWatch(overrides: Partial<SpWatch> = {}): SpWatch {
  return {
    id: ++seq,
    sp_address: nextSp(),
    derived_address: nextAddr(),
    txid: nextTxid(),
    vout: 0,
    sent_amount: '0.01000000',
    callback0conf: null,
    callback1conf: null,
    called0conf: 0,
    called1conf: 0,
    active: 1,
    inserted_ts: Math.floor(Date.now() / 1000),
    ...overrides,
  };
}

// ---------- mock fetch ----------

type FetchCall = { url: string; body: Record<string, unknown> };
let fetchCalls: FetchCall[] = [];
const originalFetch = globalThis.fetch;

before(() => {
  (globalThis as Record<string, unknown>)['fetch'] = async (
    input: string | URL,
    init?: RequestInit
  ): Promise<Response> => {
    fetchCalls.push({
      url: typeof input === 'string' ? input : String(input),
      body: JSON.parse((init?.body as string) ?? '{}') as Record<string, unknown>,
    });
    return new Response('{}', { status: 200 });
  };
});

after(() => {
  globalThis.fetch = originalFetch;
});

beforeEach(() => {
  fetchCalls = [];
});

// ---------- buildCallbackPayload ----------

describe('buildCallbackPayload', () => {
  it('includes core fields for a 0-conf tx', () => {
    const w = makeWatch({ callback0conf: 'http://example.com/cb' });
    const tx = makeTx({ confirmations: 0 });
    const p = buildCallbackPayload(w, tx);
    assert.equal(p['id'], w.id);
    assert.equal(p['address'], w.derived_address);
    assert.equal(p['sp_address'], w.sp_address);
    assert.equal(p['txid'], tx.txid);
    assert.equal(p['vout_n'], w.vout);
    assert.equal(p['sent_amount'], parseFloat(w.sent_amount!));
    assert.equal(p['confirmations'], 0);
    // no block fields on 0-conf
    assert.equal(p['blockhash'], undefined);
    assert.equal(p['blocktime'], undefined);
    assert.equal(p['blockheight'], undefined);
  });

  it('includes optional tx fields when present', () => {
    const w = makeWatch({ sent_amount: '0.00500000' });
    const tx = makeTx({
      confirmations: 1,
      hash: 'ab'.repeat(32),
      timereceived: 1_700_000_000,
      size: 250,
      vsize: 141,
      fee: -0.00001000,
      replaceable: 'no',
    });
    const p = buildCallbackPayload(w, tx);
    assert.equal(p['hash'], tx.hash);
    assert.equal(p['received'], new Date(1_700_000_000 * 1000).toISOString());
    assert.equal(p['size'], 250);
    assert.equal(p['vsize'], 141);
    assert.equal(p['fees'], 0.00001);
    assert.equal(p['replaceable'], false);
  });

  it('includes block fields when blockhash is present', () => {
    const w = makeWatch();
    const tx = makeTx({
      confirmations: 3,
      blockhash: 'cc'.repeat(32),
      blockheight: 800_000,
      blocktime: 1_710_000_000,
    });
    const p = buildCallbackPayload(w, tx);
    assert.equal(p['blockhash'], tx.blockhash);
    assert.equal(p['blockheight'], 800_000);
    assert.equal(p['blocktime'], new Date(1_710_000_000 * 1000).toISOString());
  });

  it('omits block fields when blockhash is absent', () => {
    const p = buildCallbackPayload(makeWatch(), makeTx({ confirmations: 2 }));
    assert.equal(p['blockhash'], undefined);
    assert.equal(p['blockheight'], undefined);
  });

  it('returns null sent_amount when watch has null sent_amount', () => {
    const w = makeWatch({ sent_amount: null });
    const p = buildCallbackPayload(w, makeTx());
    assert.equal(p['sent_amount'], null);
  });

  it('uses absolute value of fee', () => {
    const w = makeWatch();
    const p = buildCallbackPayload(w, makeTx({ fee: -0.0005 }));
    assert.equal(p['fees'], 0.0005);
  });

  it('replaceable is true when value is "yes"', () => {
    const p = buildCallbackPayload(makeWatch(), makeTx({ replaceable: 'yes' }));
    assert.equal(p['replaceable'], true);
  });
});

// ---------- processWatchCallbacks ----------

describe('processWatchCallbacks', () => {
  it('fires callback0conf at 0 confirmations and deactivates the watch', async () => {
    const sp    = nextSp();
    const der   = nextAddr();
    const tx    = nextTxid();
    const cb0   = 'http://test/cb0';
    const id    = watchDb.createActiveWatch(sp, der, tx, 0, '0.01', cb0);

    await processWatchCallbacks(der, makeTx({ txid: tx, confirmations: 0 }));

    assert.equal(fetchCalls.length, 1);
    assert.equal(fetchCalls[0]!.url, cb0);
    assert.equal(fetchCalls[0]!.body['confirmations'], 0);
    assert.equal(fetchCalls[0]!.body['address'], der);
    assert.equal(fetchCalls[0]!.body['sp_address'], sp);

    const w = watchDb.getWatch(id)!;
    assert.equal(w.called0conf, 1);
    assert.equal(w.active, 0); // no callback1conf → deactivated
  });

  it('fires callback1conf at 1 confirmation and deactivates the watch', async () => {
    const sp  = nextSp();
    const der = nextAddr();
    const tx  = nextTxid();
    const cb1 = 'http://test/cb1';
    const id  = watchDb.createActiveWatch(sp, der, tx, 0, '0.01', undefined, cb1);

    await processWatchCallbacks(der, makeTx({ txid: tx, confirmations: 1 }));

    assert.equal(fetchCalls.length, 1);
    assert.equal(fetchCalls[0]!.url, cb1);
    assert.equal(fetchCalls[0]!.body['confirmations'], 1);

    const w = watchDb.getWatch(id)!;
    assert.equal(w.called1conf, 1);
    assert.equal(w.active, 0);
  });

  it('does not fire callback0conf when tx has confirmations > 0', async () => {
    const sp  = nextSp();
    const der = nextAddr();
    const tx  = nextTxid();
    const id  = watchDb.createActiveWatch(sp, der, tx, 0, '0.01', 'http://test/cb0only');

    await processWatchCallbacks(der, makeTx({ txid: tx, confirmations: 1 }));
    assert.equal(fetchCalls.length, 0);

    // callback0conf is still not called; watch is not deactivated because
    // callback0conf was never satisfied (missed — still active until GC or 1-conf)
    // Actually: done0 = !callback0conf || called0conf → false; done1 = !callback1conf=true
    // So done0=false → NOT deactivated.
    assert.equal(watchDb.getWatch(id)!.active, 1);
  });

  it('does not re-fire an already-called callback0conf', async () => {
    const sp  = nextSp();
    const der = nextAddr();
    const tx  = nextTxid();
    const id  = watchDb.createActiveWatch(sp, der, tx, 0, '0.01', 'http://test/nocall');
    watchDb.markCalled0conf(id);

    await processWatchCallbacks(der, makeTx({ txid: tx, confirmations: 0 }));
    assert.equal(fetchCalls.length, 0);
  });

  it('does not re-fire an already-called callback1conf', async () => {
    const sp  = nextSp();
    const der = nextAddr();
    const tx  = nextTxid();
    const id  = watchDb.createActiveWatch(sp, der, tx, 0, '0.01', undefined, 'http://test/norecall');
    watchDb.markCalled1conf(id);

    await processWatchCallbacks(der, makeTx({ txid: tx, confirmations: 2 }));
    assert.equal(fetchCalls.length, 0);
    assert.equal(watchDb.getWatch(id)!.active, 0); // done1=true, done0=true(no cb0) → deactivated
  });

  it('fires both callbacks across two calls (0-conf then 1-conf)', async () => {
    const sp  = nextSp();
    const der = nextAddr();
    const tx  = nextTxid();
    const cb0 = 'http://test/both-cb0';
    const cb1 = 'http://test/both-cb1';
    const id  = watchDb.createActiveWatch(sp, der, tx, 0, '0.01', cb0, cb1);

    await processWatchCallbacks(der, makeTx({ txid: tx, confirmations: 0 }));
    assert.equal(fetchCalls.length, 1);
    assert.equal(fetchCalls[0]!.url, cb0);
    assert.equal(watchDb.getWatch(id)!.active, 1); // still active, waiting for 1-conf

    await processWatchCallbacks(der, makeTx({ txid: tx, confirmations: 1 }));
    assert.equal(fetchCalls.length, 2);
    assert.equal(fetchCalls[1]!.url, cb1);
    assert.equal(watchDb.getWatch(id)!.active, 0); // both done → deactivated
  });

  it('fires callbacks on multiple watches for the same derived address', async () => {
    const sp   = nextSp();
    const der  = nextAddr();
    const tx   = nextTxid();
    const cb0a = 'http://test/multi-a';
    const cb0b = 'http://test/multi-b';
    watchDb.createActiveWatch(sp, der, tx, 0, '0.01', cb0a);
    watchDb.createActiveWatch(sp, der, tx, 0, '0.01', cb0b);

    await processWatchCallbacks(der, makeTx({ txid: tx, confirmations: 0 }));
    assert.equal(fetchCalls.length, 2);
    const urls = fetchCalls.map((c) => c.url).sort();
    assert.deepEqual(urls, [cb0a, cb0b].sort());
  });

  it('ignores a derived address with no watches', async () => {
    await processWatchCallbacks(nextAddr(), makeTx({ confirmations: 0 }));
    assert.equal(fetchCalls.length, 0);
  });
});
