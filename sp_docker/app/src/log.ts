import { appendFileSync } from 'node:fs';

const TRACING  = process.env.TRACING;
const LOG_FILE = '/cnlogs/sp.log';

/**
 * Write a timestamped trace line to stderr and /cnlogs/sp.log, matching the
 * format used by other cyphernode services (proxy.log, notifier.log, etc.).
 * No-ops when TRACING env var is unset.
 *
 * NEVER pass private keys, xpriv descriptors, or RPC credentials to this function.
 */
export function log(msg: string): void {
  if (!TRACING) return;
  // Match proxy.log format: 2024-01-15T14:23:45.123 <pid> <msg>
  const ts   = new Date().toISOString().replace(/Z$/, '');
  const line = `${ts} ${process.pid} ${msg}\n`;
  process.stderr.write(line);
  try {
    appendFileSync(LOG_FILE, line);
  } catch {
    // /cnlogs not mounted (dev/test) — skip file write silently
  }
}
