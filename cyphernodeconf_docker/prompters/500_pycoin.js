const chalk = require('chalk');

const name = 'pycoin';

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [];
  },
  templates: function( props ) {
    return [ 'pycoin.env' ];
  }
};