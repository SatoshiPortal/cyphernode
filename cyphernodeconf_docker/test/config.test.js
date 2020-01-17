const Config = require('../lib/config.js');
const ApiKey = require('../lib/apikey.js');
const fs = require('fs');
const { promisify } = require( 'util' );
const existsAsync = promisify( fs.exists );
const configV010 = require('./data/config.0.1.0.json');
const configV020 = require('./data/config.0.2.0.json');
const configV022 = require('./data/config.0.2.2.json');



const expect020 = async (data) => {
  const gatekeeper_keys = JSON.parse(JSON.stringify(configV010.gatekeeper_keys));
  expect( data.gatekeeper_keys.configEntries.length ).toBe( 4 );
  for( let i=0; i<3; i++ ) {
    const configEntry = data.gatekeeper_keys.configEntries[i+1];
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
};

const expect022 = async (data) => {
  expect( data.lightning_announce ).not.toBe(undefined);
  expect( data.gatekeeper_expose ).not.toBe(undefined);
};

let configFileName;

beforeAll(() => {
  configFileName = '/tmp/config'+Math.round(Math.random()*100000000)+'.7z';
});

test( 'create config v0.1.0', () => {
  new Config(configV010);
});


test( 'create config v0.2.0', () => {
  new Config(configV020);
});


test( 'validate config v0.1.0', () => {
  const config = new Config(JSON.parse(JSON.stringify(configV010)));
  config.data.foo = "bar";
  config.data.bar = "foo";
  config.validate();
  expect( config.data.foo ).toBe( undefined );
  expect( config.data.bar ).toBe( undefined );
});


test( 'validate config v0.2.0', () => {
  const config = new Config(JSON.parse(JSON.stringify(configV020)));
  config.data.foo = "bar";
  config.data.bar = "foo";
  config.validate();
  expect( config.data.foo ).toBe( undefined );
  expect( config.data.bar ).toBe( undefined );
});

test( 'validate config v0.2.2', () => {
  const config = new Config(JSON.parse(JSON.stringify(configV022)));
  config.data.foo = "bar";
  config.data.bar = "foo";
  config.validate();
  expect( config.data.foo ).toBe( undefined );
  expect( config.data.bar ).toBe( undefined );
});

test( 'generateMigrationPathToLatest from 0.1.0', async () => {
  const config = new Config();
  const path = config.generateMigrationPathToLatest('0.1.0');
  expect( path ).toEqual( [config.migrate_0_1_0_to_0_2_0, config.migrate_0_2_0_to_0_2_2] );
});

test( 'generateMigrationPathToLatest from 0.2.0', async () => {
  const config = new Config();
  const path = config.generateMigrationPathToLatest('0.2.0');
  expect( path ).toEqual( [config.migrate_0_2_0_to_0_2_2] );
});

test( 'generateMigrationPathToLatest from 0.2.2', async () => {
  const config = new Config();
  const path = config.generateMigrationPathToLatest('0.2.2');
  expect( path ).toBe( undefined );
});

test( 'migrate 0.1.0 -> 0.2.0', async () => {
  const config = new Config();
  config.setData( JSON.parse(JSON.stringify(configV010)) );
  // deep clone gatekeeper_keys
  await config.migrate_0_1_0_to_0_2_0();
  expect020( config.data );

});

test( 'migrate 0.2.0 -> 0.2.2', async () => {
  const config = new Config();
  config.setData( JSON.parse(JSON.stringify(configV020)) );
  await config.migrate_0_2_0_to_0_2_2();
  expect022(config.data);

});

test( 'migrateFrom 0.1.0', async () => {
  const config = new Config();
  config.setData( JSON.parse(JSON.stringify(configV010)) );
  await config.migrateFrom('0.1.0');
  config.validate();
  expect020(config.data);
  expect022(config.data);
  expect( config.data.traefik_http_port ).toEqual( 80 );
  expect( config.data.traefik_https_port ).toEqual( 443 );
});



test( 'serialise', async () => {
  const config = new Config();
  config.setData( JSON.parse(JSON.stringify(configV022)) )
  const success = await config.serialize(configFileName,'test123' );
  const exists = await existsAsync(configFileName);
  expect( success ).toEqual( true );
  expect( exists ).toEqual( true );
});

test( 'deserialise', async () => {
  const config = new Config( {
    setup_version: 'setup_version'
  } );
  await config.deserialize(configFileName,'test123' );
  expect( config.data ).toEqual( configV022 );
});

