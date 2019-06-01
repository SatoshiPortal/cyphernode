const Cert = require('../lib/cert.js');

test( 'Create Cert instance', ()=>{
  const cert = new Cert();
  expect( cert.args.days ).toBe( 3650 );
});

test( 'buildConfig', ()=>{
  const cert = new Cert();
  const conf = cert.buildConfig(['127.0.0.1','localhost','gatekeeper']);
  expect( conf ).toEqual(`
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no
[req_distinguished_name]
CN = localhost
[v3_ca]
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
DNS.2 = gatekeeper
IP.1 = 127.0.0.1
`);
});


test( 'cns', () => {
  const cert = new Cert();
  const cns = cert.cns(' abc,   cde' );
  expect( cns ).toEqual([
    '127.0.0.1',
    'localhost',
    'gatekeeper',
    'abc',
    'cde'
  ]);
});

test( 'create', async ()=>{
  jest.setTimeout(999999);
  const cert = new Cert();
  const cns = cert.cns('abc,cde' );
  const r = await cert.create( cns );

  expect( r.code ).toBe(0);
  expect( r.key ).not.toBe(undefined);
  expect( r.cert ).not.toBe(undefined);
});

test( 'create throws', async ()=>{
  const cert = new Cert();
  let err;
  try {
    await cert.create();
  } catch( e ) {
    err = e;
  }
  expect( err ).not.toBe(undefined);
});