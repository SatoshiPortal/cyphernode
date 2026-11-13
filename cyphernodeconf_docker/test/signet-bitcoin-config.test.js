const fs = require('fs');
const path = require('path');
const ejs = require('ejs');

const template = fs.readFileSync(path.join(__dirname, '../templates/bitcoin/bitcoin.conf'), 'utf8');
const render = (signet, signet_network) => ejs.render(template, {
  net: 'signet',
  signet,
  signet_network,
  features: [],
  torifyables: [],
  bitcoin_prune: false,
  bitcoin_mode: 'internal',
  bitcoin_rpcuser: 'test',
  bitcoin_rpcpassword: 'test',
  bitcoin_uacomment: ''
});

test('Cyphernet keeps the miner as a signet-scoped IPv4 peer', () => {
  const config = render({
    custom: true,
    challenge: '0014dc9786c6b1c3ad2bcc45014b40384fba3419de17',
    blocktime: 30,
    patched: true,
    seednodes: ['170.75.166.64:38333', '170.75.174.86:38333']
  }, 'cyphernet');

  expect(config).toContain('signet.addnode=170.75.166.64:38333');
  expect(config).toContain('signet.signetseednode=170.75.166.64:38333');
  expect(config).toContain('signet.signetseednode=170.75.174.86:38333');
  expect(config).not.toMatch(/^addnode=/m);
});

test('another custom signet does not inherit Cyphernet peers', () => {
  const config = render({
    custom: true,
    challenge: '51',
    blocktime: 600,
    patched: false,
    seednodes: ['192.0.2.1:38333']
  }, 'custom');

  expect(config).toContain('signet.signetseednode=192.0.2.1:38333');
  expect(config).not.toMatch(/^(?:signet\.)?addnode=/m);
});
