const path = require('path');

const name = 'lightning';
const featureCondition = function(props) {
  return props.features && props.features.indexOf( name ) != -1;
}

const templates = {
  'lnd': [ path.join('lnd','lnd.conf') ],
  'c-lightning': [ path.join('c-lightning','config') ]
}

module.exports = {
  name: function() { 
    return name;
  },
  prompts: function( utils ) {
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
    },
    {
      when: featureCondition,
      type: 'input',
      name: 'lightning_external_ip',
      default: utils._getDefault( 'lightning_external_ip' ),
      validate: utils._ipOrFQDNValidator,
      message: 'What external ip does your lightning node have?'+'\n',
    }];
  },
  templates: function( props ) {
    return templates[props.lightning_implementation]
  }
};