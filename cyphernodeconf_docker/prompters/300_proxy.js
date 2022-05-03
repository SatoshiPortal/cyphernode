const chalk = require('chalk');

const name = 'proxy';

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [];
  },
  templates: function( props ) {
    return [ 'proxy.env' ];
  }
};