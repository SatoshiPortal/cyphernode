const htpasswd = require('../lib/htpasswd.js');

test( 'generate htpasswd', async ()=>{
  const pw = await htpasswd( 'test123' );
  expect( pw ).not.toBe( undefined );
});