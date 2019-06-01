const Config = require('../lib/config.js');
const ApiKey = require('../lib/apikey.js');
const fs = require('fs');

const configV010 = require('./data/config.v1.json');
const configV020 = require('./data/config.v2.json');

test( 'create config v0.1.0', () => {
  const config = new Config(configV010);
});


test( 'create config v0.2.0', () => {
  const config = new Config(configV020);
});


test( 'validate config v0.1.0', () => {
  const config = new Config(configV010);
  config.data.foo = "bar";
  config.data.bar = "foo";
  config.validate();
  expect( config.data.foo ).toBe( undefined );
  expect( config.data.bar ).toBe( undefined );
});


test( 'validate config v0.2.0', () => {
  const config = new Config(configV020);
  config.data.foo = "bar";
  config.data.bar = "foo";
  config.validate();
  expect( config.data.foo ).toBe( undefined );
  expect( config.data.bar ).toBe( undefined );
});

test( 'serialise', async () => {
  const config = new Config();
  config.setData( configV020 )
  await config.serialize('/tmp/config.7z','test123' );
  const exists = fs.existsSync('/tmp/config.7z' );
  expect( exists ).toBe( true );
});

test( 'deserialise', async () => {
  const config = new Config();
  await config.deserialize('/tmp/config.7z','test123' );
  expect( config.data ).toEqual( configV020 );
});


test( 'migrate 0.1.0 -> 0.2.0', async () => {
  const config = new Config();
  config.setData( configV010 );
  // deep clone gatekeeper_keys
  const gatekeeper_keys = JSON.parse(JSON.stringify(configV010.gatekeeper_keys));
  await config.migrate_0_1_0_to_0_2_0();
  expect( config.data.gatekeeper_keys.configEntries.length ).toBe( 4 );

  for( let i=0; i<3; i++ ) {
    const configEntry = config.data.gatekeeper_keys.configEntries[i+1];
    const oldConfigEntry = gatekeeper_keys.configEntries[i];

    const key = new ApiKey();
    key.setFromConfigEntry( configEntry )

    const oldKey = new ApiKey();
    oldKey.setFromConfigEntry( oldConfigEntry );

    expect( key.id ).toEqual( oldKey.id );
    expect( key.key ).toEqual( oldKey.key );
    expect( key.script ).toEqual( oldKey.script );

    for( let oldGroup of oldKey.groups ) {
      expect( key.groups ).toContain(oldGroup);
    }

    expect( key.groups ).toContain('stats');

  }

});


