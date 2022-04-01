const chalk = require('chalk');

const name = 'proxycron';

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [];
  },
  templates: function( props ) {
    return [ 'proxycron.env' ];
  }
};