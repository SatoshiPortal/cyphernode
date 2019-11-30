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
  'c-lightning': [ path.join('c-lightning','config') ]
};

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [
    /*
    {
      when: featureCondition,
      type: 'list',
      name: 'lightning_implementation',
      default: utils.getDefault( 'lightning_implementation' ),
      message: prefix()+'What lightning implementation do you want to use?'+utils.getHelp('lightning_implementation'),
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
    */
    {
      when: featureCondition,
      type: 'confirm',
      name: 'lightning_announce',
      default: utils.getDefault( 'lightning_announce' ),
      message: prefix()+'Do you want to announce your lightning node?'+utils.getHelp('lightning_announce'),
    },
    {
      when: (props) => { return featureCondition(props) && props.lightning_announce },
      type: 'input',
      name: 'lightning_external_ip',
      default: utils.getDefault( 'lightning_external_ip' ),
      filter: utils.trimFilter,
      validate: utils.ipOrFQDNValidator,
      message: prefix()+'What external IP does your lightning node have?'+utils.getHelp('lightning_external_ip'),
    },
    {
      when: featureCondition,
      type: 'input',
      name: 'lightning_nodename',
      default: utils.getDefault( 'lightning_nodename' ),
      filter: utils.trimFilter,
      validate: (input)=>{
        if( !input.trim() ) {
          return true;
        }
        return utils.lightningNodeNameValidator(input);
      },
      message: prefix()+'What name has your lightning node?'+utils.getHelp('lightning_nodename'),
    },
    {
      when: featureCondition,
      type: 'input',
      name: 'lightning_nodecolor',
      default: utils.getDefault( 'lightning_nodecolor' ),
      filter: utils.trimFilter,
      validate: (input)=>{
        if( !input.trim() ) {
          return true;
        }
        return utils.colorValidator(input);
      },
      message: prefix()+'What color has your lightning node?'+utils.getHelp('lightning_nodecolor'),
    }];
  },
  templates: function( props ) {
    return featureCondition(props)?templates[props.lightning_implementation]:[];
  }
};
