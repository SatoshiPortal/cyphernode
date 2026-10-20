import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { reply } from './src/http/http.ts';
import {
  handleValidateSpAddress,
  handleSend,
  handleSpWatch,
  handleSpUnwatch,
  handleGetSpWatches,
  handleNotifyTx,
} from './src/http/handlers.ts';
import { rpcConfigFromEnv } from './src/sp/rpc.ts';
import { startWatchSweep } from './src/watch/watch-sweep.ts';
import { log } from './src/log.ts';

const PORT = parseInt(process.env.SP_LISTENING_PORT ?? '8000', 10);
const NETWORK = process.env.SP_NETWORK ?? 'regtest';
// Periodic missed-notification recovery sweep. Default 10 min; set to 0 to disable.
const SWEEP_INTERVAL_MS = parseInt(process.env.SP_SWEEP_INTERVAL_MS ?? '600000', 10);

const server = createServer(async (req: IncomingMessage, res: ServerResponse) => {
  const url    = req.url    ?? '/';
  const method = req.method ?? 'GET';

  log(`[sp] ${method} ${url}`);

  if (method === 'POST' && url === '/validatespaddress') return handleValidateSpAddress(req, res);
  if (method === 'POST' && url === '/send')              return handleSend(req, res);
  if (method === 'POST' && url === '/sp_watch')          return handleSpWatch(req, res);
  if (method === 'POST' && url === '/sp_unwatch')        return handleSpUnwatch(req, res);
  if (method === 'GET'  && url === '/sp_watches')        return handleGetSpWatches(req, res);
  if (method === 'POST' && url === '/notify_tx')         return handleNotifyTx(req, res);

  reply(res, 404, { error: 'not found' });
});

server.listen(PORT, () => {
  log(`[sp] listening on :${PORT} network=${NETWORK}`);
  // Start the periodic sweep that recovers callbacks missed by the live
  // walletnotify path. Skipped if RPC isn't configured (nothing to query).
  try {
    startWatchSweep(rpcConfigFromEnv(), SWEEP_INTERVAL_MS);
  } catch (e) {
    log(`[sp] watch sweep not started (RPC not configured): ${(e as Error).message}`);
  }
});
