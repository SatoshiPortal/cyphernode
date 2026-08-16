/**
 * Minimal Bitcoin Core JSON-RPC client built on fetch.
 *
 * Configured via env vars (first match wins):
 *   BITCOIN_RPC_URL            e.g. http://user:pass@127.0.0.1:18443
 *   SPENDER_BTC_NODE_RPC_URL   e.g. bitcoin:18332/wallet  (proxy.env style)
 *   SPENDER_BTC_NODE_RPC_USER  e.g. user:pass             (proxy.env style)
 *   BITCOIN_RPC_WALLET             e.g. spending01            (optional)
 *   SPENDER_BTC_NODE_DEFAULT_WALLET  e.g. spending01.dat      (proxy.env style, fallback)
 */

import type { RpcConfig } from '../types/rpc.ts';
export type { RpcConfig };

export function rpcConfigFromEnv(): RpcConfig {
  let url = process.env.BITCOIN_RPC_URL;
  if (!url) {
    const hostPath = process.env.SPENDER_BTC_NODE_RPC_URL;
    const userPass = process.env.SPENDER_BTC_NODE_RPC_USER;
    if (hostPath && userPass) url = `http://${userPass}@${hostPath}`;
  }
  if (!url) throw new Error('BITCOIN_RPC_URL (or SPENDER_BTC_NODE_RPC_URL + SPENDER_BTC_NODE_RPC_USER) is required');
  const wallet = process.env.BITCOIN_RPC_WALLET ?? process.env.SPENDER_BTC_NODE_DEFAULT_WALLET;
  return wallet ? { url, wallet } : { url };
}

export class RpcClient {
  private readonly cfg: RpcConfig;
  constructor(cfg: RpcConfig) {
    this.cfg = cfg;
  }

  async call<T = unknown>(method: string, params: unknown[] = [], useWallet = true): Promise<T> {
    const endpoint =
      useWallet && this.cfg.wallet
        ? new URL(`/wallet/${encodeURIComponent(this.cfg.wallet)}`, this.cfg.url)
        : new URL(this.cfg.url);

    // Strip userinfo from the URL and use as Authorization: Basic header
    const auth = endpoint.username || endpoint.password ? `${decodeURIComponent(endpoint.username)}:${decodeURIComponent(endpoint.password)}` : undefined;
    endpoint.username = '';
    endpoint.password = '';

    const headers: Record<string, string> = { 'content-type': 'application/json' };
    if (auth) headers['authorization'] = `Basic ${Buffer.from(auth).toString('base64')}`;

    const body = JSON.stringify({ jsonrpc: '1.0', id: 'silent', method, params });

    const res = await fetch(endpoint.toString(), { method: 'POST', headers, body });
    if (!res.ok && res.status !== 500) {
      throw new Error(`RPC HTTP ${res.status} ${res.statusText}: ${await res.text()}`);
    }
    const json = (await res.json()) as { result: T; error: { code: number; message: string } | null };
    if (json.error) throw new Error(`RPC ${method} failed: ${json.error.code} ${json.error.message}`);
    return json.result;
  }
}
