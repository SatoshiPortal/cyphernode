import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

// Must be set before the DB module is imported so DatabaseSync uses :memory:.
process.env['SP_DB_PATH'] = ':memory:';

const {
  createWatch,
  createActiveWatch,
  activatePendingWatches,
  updateWatchSendInfo,
  getWatch,
  getWatchesByDerivedAddress,
  listActiveWatches,
  deactivateWatch,
  markCalled0conf,
  markCalled1conf,
  logSend,
  getSendByTxid,
} = await import('../src/watch/watch-db.ts');

// ---------- helpers ----------

let seq = 0;
function addr(tag: string): string { return `tb1p_${tag}_${++seq}`; }
function spAddr(tag: string): string { return `tsp1_${tag}_${++seq}`; }
function txid(tag: string): string { return tag.padEnd(64, '0'); }

// ---------- createWatch / getWatch ----------

describe('createWatch', () => {
  it('creates a pending watch and returns a numeric id', () => {
    const id = createWatch(spAddr('basic'));
    assert.equal(typeof id, 'number');
    assert.ok(id > 0);
  });

  it('created watch is active with null derived_address', () => {
    const sp = spAddr('pending');
    const id = createWatch(sp, 'http://cb0', 'http://cb1');
    const w = getWatch(id);
    assert.ok(w);
    assert.equal(w!.sp_address, sp);
    assert.equal(w!.derived_address, null);
    assert.equal(w!.callback0conf, 'http://cb0');
    assert.equal(w!.callback1conf, 'http://cb1');
    assert.equal(w!.active, 1);
    assert.equal(w!.called0conf, 0);
    assert.equal(w!.called1conf, 0);
  });

  it('stores watch with only one callback', () => {
    const id = createWatch(spAddr('one-cb'), 'http://only0');
    const w = getWatch(id);
    assert.equal(w!.callback0conf, 'http://only0');
    assert.equal(w!.callback1conf, null);
  });

  it('stores watch with no callbacks', () => {
    const id = createWatch(spAddr('no-cb'));
    const w = getWatch(id);
    assert.equal(w!.callback0conf, null);
    assert.equal(w!.callback1conf, null);
  });
});

describe('createActiveWatch', () => {
  it('creates an active watch with all fields populated', () => {
    const sp = spAddr('active');
    const derived = addr('derived');
    const tx = txid('aabbcc');
    const id = createActiveWatch(sp, derived, tx, 2, '0.05000000', 'http://c0', 'http://c1');
    const w = getWatch(id);
    assert.ok(w);
    assert.equal(w!.sp_address, sp);
    assert.equal(w!.derived_address, derived);
    assert.equal(w!.txid, tx);
    assert.equal(w!.vout, 2);
    assert.equal(w!.sent_amount, '0.05000000');
    assert.equal(w!.callback0conf, 'http://c0');
    assert.equal(w!.callback1conf, 'http://c1');
    assert.equal(w!.active, 1);
  });
});

// ---------- getWatch ----------

describe('getWatch', () => {
  it('returns undefined for a non-existent id', () => {
    assert.equal(getWatch(999_999), undefined);
  });
});

// ---------- activatePendingWatches ----------

describe('activatePendingWatches', () => {
  it('fills derived_address on pending watches for the given sp_address', () => {
    const sp = spAddr('activate');
    const id1 = createWatch(sp, 'http://cb0a');
    const id2 = createWatch(sp, 'http://cb0b');
    const derived = addr('act');

    const n = activatePendingWatches(sp, derived);
    assert.equal(n, 2);

    assert.equal(getWatch(id1)!.derived_address, derived);
    assert.equal(getWatch(id2)!.derived_address, derived);
  });

  it('does not touch watches for a different sp_address', () => {
    const spA = spAddr('sp-a');
    const spB = spAddr('sp-b');
    const idA = createWatch(spA);
    const idB = createWatch(spB);

    activatePendingWatches(spA, addr('only-a'));
    assert.equal(getWatch(idB)!.derived_address, null);
    assert.notEqual(getWatch(idA)!.derived_address, null);
  });

  it('does not touch watches that already have a derived_address', () => {
    const sp = spAddr('already-active');
    const first = addr('first');
    const second = addr('second');
    activatePendingWatches(sp, first); // no-op, no watches yet
    const id = createWatch(sp);
    activatePendingWatches(sp, first);
    activatePendingWatches(sp, second); // should not overwrite
    assert.equal(getWatch(id)!.derived_address, first);
  });

  it('returns 0 when no pending watches exist', () => {
    const n = activatePendingWatches(spAddr('ghost'), addr('ghost'));
    assert.equal(n, 0);
  });
});

// ---------- updateWatchSendInfo ----------

describe('updateWatchSendInfo', () => {
  it('fills txid/vout/sent_amount for watches that have derived_address but no txid', () => {
    const sp = spAddr('send-info');
    const derived = addr('si');
    const id = createWatch(sp);
    activatePendingWatches(sp, derived);
    assert.equal(getWatch(id)!.txid, null);

    const tx = txid('sendinfo');
    updateWatchSendInfo(derived, tx, 1, '0.00500000');
    const w = getWatch(id)!;
    assert.equal(w.txid, tx);
    assert.equal(w.vout, 1);
    assert.equal(w.sent_amount, '0.00500000');
  });

  it('does not overwrite a watch that already has a txid', () => {
    const sp = spAddr('no-overwrite');
    const derived = addr('now');
    const tx1 = txid('first111');
    const id = createActiveWatch(sp, derived, tx1, 0, '0.01');
    const tx2 = txid('second22');
    updateWatchSendInfo(derived, tx2, 0, '0.02');
    assert.equal(getWatch(id)!.txid, tx1); // unchanged
  });
});

// ---------- getWatchesByDerivedAddress ----------

describe('getWatchesByDerivedAddress', () => {
  it('returns active watches for a derived address', () => {
    const sp = spAddr('by-derived');
    const derived = addr('bd');
    const id = createActiveWatch(sp, derived, txid('bddd'), 0, '0.01');
    const watches = getWatchesByDerivedAddress(derived);
    assert.ok(watches.some((w) => w.id === id));
  });

  it('does not return inactive watches', () => {
    const sp = spAddr('inactive-filter');
    const derived = addr('if');
    const id = createActiveWatch(sp, derived, txid('ifff'), 0, '0.01');
    deactivateWatch(id);
    const watches = getWatchesByDerivedAddress(derived);
    assert.ok(!watches.some((w) => w.id === id));
  });

  it('returns empty array when no active watches exist for the address', () => {
    assert.deepEqual(getWatchesByDerivedAddress(addr('no-watch-here')), []);
  });
});

// ---------- listActiveWatches ----------

describe('listActiveWatches', () => {
  it('includes watches just created', () => {
    const sp = spAddr('list-check');
    const id = createWatch(sp);
    const list = listActiveWatches();
    assert.ok(list.some((w) => w.id === id));
  });

  it('excludes deactivated watches', () => {
    const sp = spAddr('list-deact');
    const id = createWatch(sp);
    deactivateWatch(id);
    const list = listActiveWatches();
    assert.ok(!list.some((w) => w.id === id));
  });
});

// ---------- deactivateWatch ----------

describe('deactivateWatch', () => {
  it('returns true and sets active=0', () => {
    const id = createWatch(spAddr('deact'));
    assert.equal(deactivateWatch(id), true);
    assert.equal(getWatch(id)!.active, 0);
  });

  it('returns false for a non-existent id', () => {
    assert.equal(deactivateWatch(999_888), false);
  });

  it('deactivating twice is idempotent (returns false second time)', () => {
    const id = createWatch(spAddr('deact-twice'));
    deactivateWatch(id);
    assert.equal(deactivateWatch(id), false);
  });
});

// ---------- markCalled0conf / markCalled1conf ----------

describe('markCalled0conf / markCalled1conf', () => {
  it('sets called0conf to 1', () => {
    const id = createWatch(spAddr('mark0'));
    assert.equal(getWatch(id)!.called0conf, 0);
    markCalled0conf(id);
    assert.equal(getWatch(id)!.called0conf, 1);
  });

  it('sets called1conf to 1', () => {
    const id = createWatch(spAddr('mark1'));
    assert.equal(getWatch(id)!.called1conf, 0);
    markCalled1conf(id);
    assert.equal(getWatch(id)!.called1conf, 1);
  });

  it('marks independently', () => {
    const id = createWatch(spAddr('mark-both'));
    markCalled0conf(id);
    assert.equal(getWatch(id)!.called0conf, 1);
    assert.equal(getWatch(id)!.called1conf, 0);
    markCalled1conf(id);
    assert.equal(getWatch(id)!.called1conf, 1);
  });
});

// ---------- logSend / getSendByTxid ----------

describe('logSend / getSendByTxid', () => {
  it('stores and retrieves a send by txid', () => {
    const sp = spAddr('send-log');
    const derived = addr('sl');
    const tx = txid('logtest');
    logSend(tx, sp, derived, 0, '0.02500000');
    const s = getSendByTxid(tx);
    assert.ok(s);
    assert.equal(s!.txid, tx);
    assert.equal(s!.sp_address, sp);
    assert.equal(s!.derived_address, derived);
    assert.equal(s!.vout, 0);
    assert.equal(s!.sent_amount, '0.02500000');
  });

  it('returns undefined for unknown txid', () => {
    assert.equal(getSendByTxid(txid('unknown')), undefined);
  });

  it('INSERT OR REPLACE overwrites on duplicate txid', () => {
    const sp = spAddr('replace');
    const derived1 = addr('r1');
    const derived2 = addr('r2');
    const tx = txid('replace1');
    logSend(tx, sp, derived1, 0, '0.01');
    logSend(tx, sp, derived2, 1, '0.02');
    const s = getSendByTxid(tx)!;
    assert.equal(s.derived_address, derived2);
    assert.equal(s.vout, 1);
  });
});

// ---------- multiple watches per sp_address ----------

describe('multiple watches per sp_address', () => {
  it('supports independent watches for the same sp_address', () => {
    const sp = spAddr('multi');
    const id1 = createWatch(sp, 'http://cb-1a', 'http://cb-1b');
    const id2 = createWatch(sp, 'http://cb-2a', 'http://cb-2b');
    const id3 = createWatch(sp, 'http://cb-3a');

    assert.notEqual(id1, id2);
    assert.notEqual(id2, id3);

    // activating assigns the same derived_address to all three
    const derived = addr('multi');
    activatePendingWatches(sp, derived);
    assert.equal(getWatch(id1)!.derived_address, derived);
    assert.equal(getWatch(id2)!.derived_address, derived);
    assert.equal(getWatch(id3)!.derived_address, derived);

    // deactivating one doesn't affect the others
    deactivateWatch(id1);
    const active = getWatchesByDerivedAddress(derived);
    assert.ok(!active.some((w) => w.id === id1));
    assert.ok(active.some((w) => w.id === id2));
    assert.ok(active.some((w) => w.id === id3));
  });
});
