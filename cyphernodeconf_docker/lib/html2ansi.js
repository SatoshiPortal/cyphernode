/* eslint-disable camelcase */
const parse5 = require('parse5');
const chalk = require('chalk');

const options = {
  scriptingEnabled: false
};

const convert = function(data){

  // recursively flatten
  let v = data.childNodes && data.childNodes.length?
    data.childNodes.map(d=> convert(d)).join(''):
    data.value?data.value:'';

  switch (data.tagName){
  case 'br':
    v += '\n';
    break;
  case 'font':
    if ( data.attrs && data.attrs.length ) {
      for ( let attr of data.attrs ) {
        if ( attr.name === 'color' && /^#[a-f0-9]{6}$/.test(attr.value) ) {
          v = chalk.hex(attr.value)(v);
        }
        if ( attr.name === 'bold' && attr.value === 'true' ) {
          v = chalk.bold(v);
        }
        if ( attr.name === 'italic' && attr.value === 'true' ) {
          v = chalk.italic(v);
        }
        if ( attr.name === 'underline' && attr.value === 'true' ) {
          v = chalk.underline(v);
        }
        if ( attr.name === 'strikethrough' && attr.value === 'true' ) {
          v = chalk.strikethrough(v);
        }
      }
    }
    break;
  }
  return v;
};

module.exports = function(html){
  return convert(parse5.parseFragment(html, options));
};
