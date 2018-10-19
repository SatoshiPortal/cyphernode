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
      message: prefix()+'What features do you want to add to your cyphernode?'+'\n',
      choices: utils._featureChoices()
    },
    {
      type: 'list',
      name: 'net',
      default: utils._getDefault( 'net' ),
      message: prefix()+'What net do you want to run on?'+'\n',
      choices: [{
        name: "Testnet",
        value: "testnet"
      },{
        name: "Mainnet",
        value: "mainnet"
      }]
    },
    {
      type: 'input',
      name: 'username',
      default: utils._getDefault( 'username' ),
      message: prefix()+'What username will cyphernode run under?'+'\n',
      filter: utils._trimFilter,
      validate: utils._usernameValidator
    },
    {
      type: 'input',
      name: 'xpub',
      default: utils._getDefault( 'xpub' ),
      message: prefix()+'What is your xpub to watch?'+'\n',
      filter: utils._trimFilter,
      validate: utils._xkeyValidator
    },
    {
      type: 'input',
      name: 'derivation_path',
      default: utils._getDefault( 'derivation_path' ),
      message: prefix()+'What is your address derivation path?'+'\n',
      filter: utils._trimFilter,
      validate: utils._derivationPathValidator
    }];
  },
  templates: function( props ) {
    return [];
  }
};