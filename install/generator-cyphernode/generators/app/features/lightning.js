const featureCondition = function(props) {
  return props.features && props.features.indexOf( 'lightning' ) != -1;
}

module.exports = function( utils ) {
  return [{
    when: featureCondition,
    type: 'list',
    name: 'lightning_implementation',
    default: utils._getDefault( 'lightning_implementation' ),
    message: 'What lightning implementation do you want to use?'+'\n',
    choices: [
      {
        name: 'C-lightning',
        value: 'c-lightning'
      },
      {
        name: 'LND',
        value: 'lnd'
      }
    ]
  }];
};