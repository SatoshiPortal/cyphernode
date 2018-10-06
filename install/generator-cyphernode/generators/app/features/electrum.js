const featureCondition = function(props) {
  return props.features && props.features.indexOf( 'electrum' ) != -1;
}

module.exports = function( utils ) {
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
};