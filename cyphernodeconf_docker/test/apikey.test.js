const ApiKey = require('../lib/apikey.js');


test( 'Create ApiKey instance', ()=>{
  const apiKey = new ApiKey('testId',['group1','group2']);
  expect( apiKey ).not.toBe( undefined );
  expect( apiKey.id ).toEqual( 'testId' );
  expect( apiKey.groups ).toEqual( ['group1','group2'] );
  expect( apiKey.key ).toBe( undefined );
  expect( apiKey.script ).toEqual( 'eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}' );
});

test( 'Create ApiKey instance and randomise it', async ()=>{
  const apiKey = new ApiKey('testId',['group1','group2']);
  await apiKey.randomiseKey();
  expect( apiKey ).not.toBe( undefined );
  expect( apiKey.id ).toEqual( 'testId' );
  expect( apiKey.groups ).toEqual( ['group1','group2'] );
  expect( apiKey.key ).not.toBe( undefined );
  expect( apiKey.script ).toEqual( 'eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}' );
});

test( 'Create ApiKey instance, randomise it and use getters', async ()=>{
  const apiKey = new ApiKey('testId',['group1','group2']);
  await apiKey.randomiseKey();
  const keyString = apiKey.getKey();
  const script = apiKey.script;
  expect( keyString ).not.toBe( undefined );
  expect( apiKey.id ).toEqual( 'testId' );
  expect( apiKey.getClientInformation() ).toEqual( 'testId='+keyString );
  expect( apiKey.getConfigEntry() ).toEqual( `kapi_id="testId";kapi_key="${keyString}";kapi_groups="group1,group2";${script}` );
});

test( 'Set properties of ApiKey instance from config entry', async () => {
  const configEntry = 'kapi_id="000";kapi_key="b1fdc782037609f8ecc063ac192e92d57544263a950c637ed6b7d79cc9eb9f95";kapi_groups="stats";eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}';
  const apiKey = new ApiKey();
  apiKey.setFromConfigEntry(configEntry);
  expect( apiKey.id ).toEqual('000');
  expect( apiKey.groups ).toEqual(['stats']);
  expect( apiKey.key ).toEqual('b1fdc782037609f8ecc063ac192e92d57544263a950c637ed6b7d79cc9eb9f95');
  expect( apiKey.script ).toEqual('eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}')
})