const featureCondition = function(props) {
  return props.features && props.features.indexOf( 'bitcoin' ) != -1;
};

module.exports = function( utils ) {
	return [{
    when: featureCondition,
    type: 'confirm',
    name: 'bitcoin_prune',
    default: utils._getDefault( 'bitcoin_prune' ),
    message: 'Run bitcoin node in prune mode?'+'\n',
  },
  {
    when: featureCondition,
    type: 'input',
    name: 'bitcoin_external_ip',
    default: utils._getDefault( 'bitcoin_external_ip' ),
    validate: utils._ipValidator,
    message: 'What external ip does your bitcoin full node have?'+'\n',
  }];
};