const path = require('path');
const chalk = require('chalk');

const name = 'lightning';

const capitalise = function( txt ) {
  return txt.charAt(0).toUpperCase() + txt.substr(1);
};

const prefix = function() {
  return chalk.green(capitalise(name)+': ');
};

const featureCondition = function(props) {
  return props.features && props.features.indexOf( name ) != -1;
};

const templates = {
  'lnd': [ path.join('lnd','lnd.conf') ],
  'c-lightning': [ path.join('c-lightning','config'), path.join('c-lightning','bitcoin.conf') ]
};

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
      message: prefix()+'What lightning implementation do you want to use?'+'\n',
      choices: [
        {
          name: 'C-lightning',
          value: 'c-lightning'
        }
        /*,
        {
          name: 'LND',
          value: 'lnd'
        }
        */
      ]
    },
    {
      when: featureCondition,
      type: 'input',
      name: 'lightning_external_ip',
      default: utils._getDefault( 'lightning_external_ip' ),
      filter: utils._trimFilter,
      validate: utils._ipOrFQDNValidator,
      message: prefix()+'What external ip does your lightning node have?'+'\n',
    },
    {
      when: featureCondition,
      type: 'input',
      name: 'lightning_nodename',
      default: utils._getDefault( 'lightning_nodename' ),
      filter: utils._trimFilter,
      validate: utils._notEmptyValidator,
      message: prefix()+'What name has your lightning node?'+'\n',
    },
    {
      when: featureCondition,
      type: 'input',
      name: 'lightning_nodecolor',
      default: utils._getDefault( 'lightning_nodecolor' ),
      filter: utils._trimFilter,
      validate: utils._colorValidator,
      message: prefix()+'What color has your lightning node?'+'\n',
    }];
  },
  templates: function( props ) {
    return templates[props.lightning_implementation]
  }
};