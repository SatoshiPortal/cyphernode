const fs = require('fs');
const path = require('path');
const ejs = require('ejs');

const repo = path.resolve(__dirname, '../..');
const read = file => fs.readFileSync(path.join(repo, file), 'utf8');

test('installer and proxy use the same published CLN release', () => {
  const setup = read('dist/setup.sh');
  const version = setup.match(/^LIGHTNING_VERSION="([^"]+)"$/m)[1];
  const compose = read('cyphernodeconf_docker/templates/installer/docker/docker-compose.yaml');
  const imageTemplate = compose.match(/^    image: (elementsproject\/lightningd:<%= lightning_version %>)$/m)[1];
  const image = ejs.render(imageTemplate, {lightning_version: version});
  const proxyDockerfile = read('proxy_docker/Dockerfile');

  expect(image).toBe('elementsproject/lightningd:v26.06.9');
  expect(proxyDockerfile).toContain(`COPY --from=${image} /usr/local/bin/lightning-cli`);
});

test('CLN entrypoint still renders both direct and Tor launch paths', () => {
  const template = read('cyphernodeconf_docker/templates/lightning/c-lightning/entrypoint.sh');
  const direct = ejs.render(template, {features: ['lightning'], torifyables: []});
  const tor = ejs.render(template, {features: ['lightning', 'tor'], torifyables: ['tor_lightning']});

  expect(direct).toContain('exec lightningd --lightning-dir=/.lightning');
  expect(direct).toContain('pip3 install --user -r "$plugin/requirements.txt"');
  expect(tor).toContain('exec lightningd --lightning-dir=/.lightning --proxy=$TORIP:9050');
});

test('official CLN config omits the obsolete offers flag', () => {
  const config = read('cyphernodeconf_docker/templates/lightning/c-lightning/config');
  expect(config).not.toMatch(/^experimental-offers$/m);
});
