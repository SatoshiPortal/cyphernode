const chalk = require('chalk');

const name = 'otsclient';

const capitalise = function( txt ) {
  return txt.charAt(0).toUpperCase() + txt.substr(1);
};

const prefix = function() {
  return chalk.green(capitalise(name)+': ');
};

const featureCondition = function(props) {
  return props.features && props.features.indexOf( name ) != -1;
};

module.exports = {
  name: function() { 
    return name;
  },
  prompts: function( utils ) {
    return [];
  },
  templates: function( props ) {
    return [];
  }
};