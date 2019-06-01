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
      message: prefix()+'What features do you want to add to your cyphernode?'+utils.getHelp('features'),
      choices: utils.featureChoices()
    },
    {
      type: 'list',
      name: 'net',
      default: utils.getDefault( 'net' ),
      message: prefix()+'What net do you want to run on?'+utils.getHelp('net'),
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
      default: utils.getDefault( 'run_as_different_user' ),
      message: prefix()+'Run as different user?'+utils.getHelp('run_as_different_user')
    },
    {
      when: function( props ) {
        return props.run_as_different_user;
      },
      type: 'input',
      name: 'username',
      default: utils.getDefault( 'username' ),
      message: prefix()+'What username will cyphernode run under?'+utils.getHelp('username'),
      filter: utils.trimFilter,
      validate: utils.usernameValidator
    },
    {
      type: 'confirm',
      name: 'use_xpub',
      default: utils.getDefault( 'use_xpub' )||false,
      message: prefix()+'Use a default xpub key to watch or generate adresses?'+utils.getHelp('use_xpub'),
    },
    {
      when: function( props ) {
        return props.use_xpub;
      },
      type: 'input',
      name: 'xpub',
      default: utils.getDefault( 'xpub' ),
      message: prefix()+'What is your default xpub key?'+utils.getHelp('xpub'),
      filter: utils.trimFilter,
      validate: utils.xkeyValidator
    },
    {
      when: function( props ) {
        return props.use_xpub;
      },
      type: 'input',
      name: 'derivation_path',
      default: utils.getDefault( 'derivation_path' ),
      message: prefix()+'What is your default derivation path?'+utils.getHelp('derivation_path'),
      filter: utils.trimFilter,
      validate: utils.derivationPathValidator
    }];
  },
  templates: function( props ) {
    return [];
  }
};
