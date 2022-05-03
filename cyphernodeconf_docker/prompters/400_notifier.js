const chalk = require('chalk');

const name = 'notifier';

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [];
  },
  templates: function( props ) {
    return [ 'notifier.env' ];
  }
};