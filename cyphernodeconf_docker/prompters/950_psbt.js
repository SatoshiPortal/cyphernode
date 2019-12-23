const chalk = require('chalk');

const name = 'PSBT';

const capitalise = function( txt ) {
  return txt.charAt(0).toUpperCase() + txt.substr(1);
};

const prefix = function() {
  return chalk.green(capitalise(name)+': ');
};

module.exports = {
  name: function() {
    return name;
  },
  prompts: function( utils ) {
    return [
      {
        type: 'confirm',
        name: 'psbt_wallet_active',
        default: utils.getDefault( 'psbt_wallet_active' )||false,
        message: prefix()+'Activate PSBT wallet?'+utils.getHelp('psbt_wallet_active'),
      },
      {
        when: function( props ) {
          return props.psbt_wallet_active;
        },
        type: 'input',
        name: 'psbt_xpub',
        default: utils.getDefault( 'psbt_xpub' ),
        message: prefix()+'What is the xpub key for the PSBT wallet?'+utils.getHelp('psbt_xpub'),
        filter: utils.trimFilter,
        validate: utils.xkeyValidator
      }];
  },
  templates: function( props ) {
    return []
  }
};
