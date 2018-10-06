const name = 'electrum';
const featureCondition = function(props) {
  return props.features && props.features.indexOf( name ) != -1;
}

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
      message: 'What electrum implementation do you want to use?'+'\n',
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
  env: function( props ) {
    return 'VAR0=VALUE0\nVAR1=VALUE1'
  },
  templates: function( props ) {
    return [];
  }
};