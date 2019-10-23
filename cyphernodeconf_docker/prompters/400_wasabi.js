const path = require('path');
const chalk = require('chalk');

const name = 'wasabi';

const capitalise = function( txt ) {
  return txt.charAt(0).toUpperCase() + txt.substr(1);
};

const prefix = function() {
  return chalk.green(capitalise(name)+': ');
};

const featureCondition = function(props) {
  return props.features && props.features.indexOf( name ) != -1;
};

const correctCountValidator = function( count ) {
  if ( isNaN( count ) ) {
    throw 'Count should be a number';
  }

  if ( count < 1 || count > 2 ) {
    throw 'Count should be between 1 and 2';
  }

  return true;
};

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [
      {
        when: featureCondition,
        type: 'input',
        name: 'wasabi_mixuntil',
        default: utils.getDefault( 'wasabi_mixuntil' ),
        filter: utils.trimFilter,
        validate: utils.notEmptyValidator,
        message: prefix()+'What anonymity set do you want to reach?'+utils.getHelp('wasabi_mixuntil')
      },
      {
        when: featureCondition,
        type: 'input',
        name: 'wasabi_instance_count',
        default: utils.getDefault( 'wasabi_instance_count' ),
        filter: utils.trimFilter,
        validate: function( count ) {
          return utils.notEmptyValidator( count ) && correctCountValidator( count );
        },
        message: prefix()+'How many wasabi coin join instances do you want to run?'+utils.getHelp('wasabi_instance_count')
      }
    ];
  },
  templates: function( props ) {
    let files = ['Config.json'];
    if( props.net === 'regtest' ) {
      files = files.concat( ['backend/Config.json', 'backend/CcjRoundConfig.json'] )
    }
    return featureCondition(props)?files:[];
  }
};
