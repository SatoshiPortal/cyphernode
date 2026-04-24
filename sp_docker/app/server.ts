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
import { log } from './src/log.ts';

const PORT = parseInt(process.env.SP_LISTENING_PORT ?? '8000', 10);
const NETWORK = process.env.SP_NETWORK ?? 'regtest';

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
});
