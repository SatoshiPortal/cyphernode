import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import type { SpWatch, SpSend } from '../types/watch.ts';

const DB_PATH = process.env.SP_DB_PATH ?? '/sp/data/sp_watches.db';

mkdirSync(dirname(DB_PATH), { recursive: true });

const db = new DatabaseSync(DB_PATH);

db.exec('PRAGMA journal_mode = WAL');

db.exec(`
  CREATE TABLE IF NOT EXISTS sp_watches (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    sp_address    TEXT    NOT NULL,
    derived_address TEXT,
    txid          TEXT,
    vout          INTEGER,
    sent_amount    TEXT,
    callback0conf TEXT,
    callback1conf TEXT,
    called0conf   INTEGER NOT NULL DEFAULT 0,
    called1conf   INTEGER NOT NULL DEFAULT 0,
    active        INTEGER NOT NULL DEFAULT 1,
    inserted_ts   INTEGER NOT NULL DEFAULT (unixepoch())
  );
  CREATE INDEX IF NOT EXISTS idx_spw_derived ON sp_watches (derived_address);
  CREATE INDEX IF NOT EXISTS idx_spw_sp_addr ON sp_watches (sp_address);
  CREATE INDEX IF NOT EXISTS idx_spw_active  ON sp_watches (active);

  CREATE TABLE IF NOT EXISTS sp_sends (
    txid            TEXT PRIMARY KEY,
    sp_address      TEXT NOT NULL,
    derived_address TEXT NOT NULL,
    vout            INTEGER NOT NULL,
    sent_amount      TEXT NOT NULL,
    inserted_ts     INTEGER NOT NULL DEFAULT (unixepoch())
  );
  CREATE INDEX IF NOT EXISTS idx_sps_sp_addr ON sp_sends (sp_address);
`);

// ---------- watches ----------

export function createWatch(
  spAddress: string,
  callback0conf?: string,
  callback1conf?: string,
): number {
  const result = db.prepare(
    'INSERT INTO sp_watches (sp_address, callback0conf, callback1conf) VALUES (?, ?, ?)',
  ).run(spAddress, callback0conf ?? null, callback1conf ?? null);
  return result.lastInsertRowid as number;
}

export function createActiveWatch(
  spAddress: string,
  derivedAddress: string,
  txid: string,
  vout: number,
  amountBtc: string,
  callback0conf?: string,
  callback1conf?: string,
): number {
  const result = db.prepare(
    `INSERT INTO sp_watches
       (sp_address, derived_address, txid, vout, sent_amount, callback0conf, callback1conf)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(spAddress, derivedAddress, txid, vout, amountBtc, callback0conf ?? null, callback1conf ?? null);
  return result.lastInsertRowid as number;
}

// Set derived_address on all pending (no derived_address yet) watches for an sp_address.
// Returns the number of rows updated.
export function activatePendingWatches(spAddress: string, derivedAddress: string): number {
  const result = db.prepare(
    `UPDATE sp_watches SET derived_address = ?
     WHERE sp_address = ? AND derived_address IS NULL AND active = 1`,
  ).run(derivedAddress, spAddress);
  return result.changes as number;
}

// Undo activatePendingWatches when a send fails before broadcast: clear the
// derived_address back to NULL on watches that were just activated for this
// sp_address/derived_address and have not yet been tied to a txid. This keeps
// the watch pending (re-usable by a retried send) instead of leaving it
// pointing at a derived address that will never be paid.
// Returns the number of rows reverted.
export function revertPendingActivation(spAddress: string, derivedAddress: string): number {
  const result = db.prepare(
    `UPDATE sp_watches SET derived_address = NULL
     WHERE sp_address = ? AND derived_address = ? AND txid IS NULL AND active = 1`,
  ).run(spAddress, derivedAddress);
  return result.changes as number;
}

// Fill in txid / vout / sent_amount on watches that have a derived_address but no txid yet.
export function updateWatchSendInfo(
  derivedAddress: string,
  txid: string,
  vout: number,
  amountBtc: string,
): void {
  db.prepare(
    `UPDATE sp_watches SET txid = ?, vout = ?, sent_amount = ?
     WHERE derived_address = ? AND txid IS NULL AND active = 1`,
  ).run(txid, vout, amountBtc, derivedAddress);
}

export function getWatch(id: number): SpWatch | undefined {
  return db.prepare('SELECT * FROM sp_watches WHERE id = ?').get(id) as unknown as SpWatch | undefined;
}

export function getWatchesByDerivedAddress(derivedAddress: string): SpWatch[] {
  return db.prepare(
    'SELECT * FROM sp_watches WHERE derived_address = ? AND active = 1',
  ).all(derivedAddress) as unknown as SpWatch[];
}

export function listActiveWatches(): SpWatch[] {
  return db.prepare(
    'SELECT * FROM sp_watches WHERE active = 1 ORDER BY inserted_ts DESC',
  ).all() as unknown as SpWatch[];
}

// Active watches that have been tied to a broadcast tx (txid + derived_address).
// These are the only watches the periodic sweep can reconcile against the chain;
// pending watches (no derived_address/txid yet) have nothing to check.
export function listActiveWatchesWithTxid(): SpWatch[] {
  return db.prepare(
    `SELECT * FROM sp_watches
     WHERE active = 1 AND txid IS NOT NULL AND derived_address IS NOT NULL
     ORDER BY inserted_ts ASC`,
  ).all() as unknown as SpWatch[];
}

export function deactivateWatch(id: number): boolean {
  const result = db.prepare('UPDATE sp_watches SET active = 0 WHERE id = ? AND active = 1').run(id);
  return (result.changes as number) > 0;
}

// Deactivates watches matching sp_address AND the provided callback URLs.
// At least one callback URL must be provided; only rows where BOTH supplied
// URLs match are deactivated (unspecified callbacks are treated as wildcards).
export function deactivateWatchesBySpAddress(
  spAddress: string,
  callback0conf?: string,
  callback1conf?: string,
): number {
  const result = db.prepare(`
    UPDATE sp_watches SET active = 0
    WHERE sp_address = :sp
      AND active = 1
      AND (:cb0 IS NULL OR callback0conf = :cb0)
      AND (:cb1 IS NULL OR callback1conf = :cb1)
  `).run({ sp: spAddress, cb0: callback0conf ?? null, cb1: callback1conf ?? null });
  return result.changes as number;
}

export function markCalled0conf(id: number): void {
  db.prepare('UPDATE sp_watches SET called0conf = 1 WHERE id = ?').run(id);
}

export function markCalled1conf(id: number): void {
  db.prepare('UPDATE sp_watches SET called1conf = 1 WHERE id = ?').run(id);
}

// ---------- sends log ----------

export function logSend(
  txid: string,
  spAddress: string,
  derivedAddress: string,
  vout: number,
  amountBtc: string,
): void {
  db.prepare(
    `INSERT OR REPLACE INTO sp_sends (txid, sp_address, derived_address, vout, sent_amount)
     VALUES (?, ?, ?, ?, ?)`,
  ).run(txid, spAddress, derivedAddress, vout, amountBtc);
}

export function getSendByTxid(txid: string): SpSend | undefined {
  return db.prepare('SELECT * FROM sp_sends WHERE txid = ?').get(txid) as unknown as SpSend | undefined;
}
