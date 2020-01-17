const Archive = require('../lib/archive.js');
const tmp = require('tmp');
const path = require('path');

test( 'Create Archive instance', ()=>{
  new Archive( '/tmp/testArchive.7z', 'test123' );
});

test( 'Write, Read, Delete', async ()=>{
  const tmpDir = tmp.dirSync();
  const archive = new Archive( path.join(tmpDir.name,'archive.7z'), 'test123' );

  await archive.writeEntry('testEntry', 'testContent' );

  const c0 = await  archive.readEntry( 'testEntry' );

  expect( c0.value ).toEqual( 'testContent' );

  await archive.deleteEntry('testEntry');

  const c1 = await archive.readEntry( 'testEntry' );

  expect( c1.value ).toBe( '' );

  tmpDir.removeCallback();
});
