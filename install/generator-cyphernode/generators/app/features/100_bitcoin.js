const name = 'bitcoin';
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
  },
  env: function( props ) {
    return 'VAR0=VALUE0\nVAR1=VALUE1'
  }
};