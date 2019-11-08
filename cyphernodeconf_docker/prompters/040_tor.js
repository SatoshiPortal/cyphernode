const chalk = require('chalk');

const name = 'tor';

const capitalise = function( txt ) {
  return txt.charAt(0).toUpperCase() + txt.substr(1);
};

const prefix = function() {
  return chalk.green(capitalise(name)+': ');
};

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [
    ];
  },
  templates: function( props ) {
    return [ 'torrc', 'curlcfg' ];
  }
};
