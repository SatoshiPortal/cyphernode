const chalk = require('chalk');

const name = 'electrum';

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
    return [{
      when: featureCondition,
      type: 'list',
      name: 'electrum_implementation',
      default: utils._getDefault( 'electrum_implementation' ),
      message: prefix()+'What electrum implementation do you want to use?'+'\n',
      choices: [
        {
          name: 'Electrum personal server',
          value: 'eps'
        },
        {
          name: 'Electrumx server',
          value: 'elx'
        }
      ]
    }];
  },
  templates: function( props ) {
    return [];
  }
};