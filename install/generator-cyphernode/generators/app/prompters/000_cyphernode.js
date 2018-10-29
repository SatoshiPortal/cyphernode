const chalk = require('chalk');

const name = 'cyphernode';

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
    return [{
      // https://github.com/SBoudrias/Inquirer.js#question
      // input, confirm, list, rawlist, expand, checkbox, password, editor
      type: 'checkbox',
      name: 'features',
      message: prefix()+'What features do you want to add to your cyphernode?'+utils._getHelp('features'),
      choices: utils._featureChoices()
    },
    {
      type: 'list',
      name: 'net',
      default: utils._getDefault( 'net' ),
      message: prefix()+'What net do you want to run on?'+utils._getHelp('net'),
      choices: [{
        name: "Testnet",
        value: "testnet"
      },{
        name: "Mainnet",
        value: "mainnet"
      }]
    },
    {
      type: 'confirm',
      name: 'run_as_different_user',
      default: utils._getDefault( 'run_as_different_user' ),
      message: prefix()+'Run as different user?'+utils._getHelp('gatekeeper_edit_ipwhitelist')
    },
    {
      when: function( props ) { 
        return props.run_as_different_user;
      },
      type: 'input',
      name: 'username',
      default: utils._getDefault( 'username' ),
      message: prefix()+'What username will cyphernode run under?'+utils._getHelp('username'),
      filter: utils._trimFilter,
      validate: utils._usernameValidator
    },
    {
      type: 'input',
      name: 'xpub',
      default: utils._getDefault( 'xpub' ),
      message: prefix()+'What is your xpub to watch?'+utils._getHelp('xpub'),
      filter: utils._trimFilter,
      validate: utils._xkeyValidator
    },
    {
      type: 'input',
      name: 'derivation_path',
      default: utils._getDefault( 'derivation_path' ),
      message: prefix()+'What is your address derivation path?'+utils._getHelp('derivation_path'),
      filter: utils._trimFilter,
      validate: utils._derivationPathValidator
    }];
  },
  templates: function( props ) {
    return [];
  }
};