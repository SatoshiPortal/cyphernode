const name = require('../lib/name.js');


test( 'Create new random name', ()=>{
  const n = name.generate();
  expect( n ).not.toBe( undefined )
});