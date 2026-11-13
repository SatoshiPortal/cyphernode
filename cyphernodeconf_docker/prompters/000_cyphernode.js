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
      },{
        name: "Signet",
        value: "signet"
      },{
        name: "RegTest",
        value: "regtest"
      }]
    },
    {
      when: function(props) { return props.net === 'signet'; },
      type: 'list',
      name: 'signet_network',
      default: utils.getDefault( 'signet_network' ) || 'public',
      message: prefix()+'Which signet?'+utils.getHelp('signet_network'),
      choices: [{
        name: "Public signet",
        value: "public"
      },{
        name: "Cyphernet (30 second blocks)",
        value: "cyphernet"
      },{
        name: "Another custom signet",
        value: "custom"
      }]
    },
    {
      when: function(props) { return props.net === 'signet' && props.signet_network === 'custom'; },
      type: 'input',
      name: 'signet_challenge',
      default: utils.getDefault( 'signet_challenge' ),
      filter: utils.trimFilter,
      validate: function( input ) {
        return /^[0-9a-fA-F]+$/.test( input ) && input.length % 2 === 0 || 'Enter the signet challenge script in hex';
      },
      message: prefix()+'What is the signet challenge (hex)?'+utils.getHelp('signet_challenge')
    },
    {
      when: function(props) { return props.net === 'signet' && props.signet_network === 'custom'; },
      type: 'input',
      name: 'signet_blocktime',
      default: utils.getDefault( 'signet_blocktime' ) || 600,
      filter: function( input ) { return parseInt( input, 10 ); },
      validate: function( input ) {
        return Number.isInteger( input ) && input > 0 || 'Enter the block time in seconds';
      },
      message: prefix()+'What is the signet block time in seconds?'+utils.getHelp('signet_blocktime')
    },
    {
      when: function(props) { return props.net === 'signet' && props.signet_network === 'custom'; },
      type: 'input',
      name: 'signet_seednodes',
      default: utils.getDefault( 'signet_seednodes' ),
      filter: utils.trimFilter,
      validate: function( input ) {
        return /^[A-Za-z0-9.\-]+:[0-9]+(,[A-Za-z0-9.\-]+:[0-9]+)*$/.test( input ) || 'Enter host:port, separated by commas';
      },
      message: prefix()+'What are the signet seed nodes (host:port, comma separated)?'+utils.getHelp('signet_seednodes')
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
    },
    {
      when: function(props) { return props.features.indexOf('elements') !== -1  },
      type: 'confirm',
      name: 'use_elements_xpub',
      default: utils.getDefault( 'use_elements_xpub' )||false,
      message: prefix()+'Use a default elements xpub key to watch or generate adresses?'+utils.getHelp('use_elements_xpub'),
    },
    {
      when: function( props ) {
        return props.use_elements_xpub;
      },
      type: 'input',
      name: 'elements_xpub',
      default: utils.getDefault( 'elements_xpub' ),
      message: prefix()+'What is your default elements xpub key?'+utils.getHelp('elements_xpub'),
      filter: utils.trimFilter,
      validate: utils.xkeyValidator
    },
    {
      when: function( props ) {
        return props.use_elements_xpub;
      },
      type: 'input',
      name: 'elements_derivation_path',
      default: utils.getDefault( 'elements_derivation_path' ),
      message: prefix()+'What is your default elements derivation path?'+utils.getHelp('elements_derivation_path'),
      filter: utils.trimFilter,
      validate: utils.derivationPathValidator
    }];
  },
  templates: function( props ) {
    return ['info.json'];
  }
};
