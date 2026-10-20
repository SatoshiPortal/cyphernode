#!/usr/bin/env node
// Minimal HTTP server that logs incoming POST callbacks to stdout.
// Usage: node callback-listener.js [port]
// Default port: 9000

const { createServer } = require('node:http');

const PORT = parseInt(process.argv[2] ?? '9000', 10);

const server = createServer((req, res) => {
  let body = '';
  req.on('data', chunk => { body += chunk; });
  req.on('end', () => {
    const ts = new Date().toISOString();
    console.log(`\n[${ts}] ${req.method} ${req.url}`);
    console.log('Headers:', JSON.stringify(Object.fromEntries(
      Object.entries(req.headers).filter(([k]) => ['content-type','content-length'].includes(k))
    )));
    try {
      console.log('Body:', JSON.stringify(JSON.parse(body), null, 2));
    } catch {
      console.log('Body (raw):', body);
    }
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end('{"ok":true}');
  });
});

server.listen(PORT, () => {
  console.log(`Callback listener running on http://0.0.0.0:${PORT}`);
  console.log('Waiting for callbacks...\n');
});
