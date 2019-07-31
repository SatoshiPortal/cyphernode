const chalk = require('chalk');

const name = 'otsclient';

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [];
  },
  templates: function( props ) {
    return [ 'bitcoin.conf' ];
  }
};
