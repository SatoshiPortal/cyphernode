import { type IncomingMessage, type ServerResponse } from 'node:http';

export function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (chunk: Buffer) => { body += chunk.toString(); });
    req.on('end', () => resolve(body));
    req.on('error', reject);
  });
}

export function reply(res: ServerResponse, status: number, body: unknown): void {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
}

// Reads and JSON-parses the request body. Sends an error reply and returns
// null on failure so handlers can early-return cleanly.
export async function parseBody(
  req: IncomingMessage,
  res: ServerResponse,
): Promise<Record<string, unknown> | null> {
  let raw: string;
  try { raw = await readBody(req); } catch {
    reply(res, 400, { error: 'bad request' });
    return null;
  }
  try { return JSON.parse(raw) as Record<string, unknown>; } catch {
    reply(res, 400, { error: 'invalid JSON' });
    return null;
  }
}
