const chalk = require('chalk');

const name = 'bitcoin';

const capitalise = function( txt ) {
  return txt.charAt(0).toUpperCase() + txt.substr(1);
};

const prefix = function() {
  return chalk.green(capitalise(name)+': ');
};

const bitcoinExternal = function(props) {
  return props.bitcoin_mode === 'external'
};

const bitcoinInternal = function(props) {
  return props.bitcoin_mode === 'internal'
};

module.exports = {
  name: function() { 
    return name;
  },
  prompts: function( utils ) {
    return [
    {
      type: 'list',
      name: 'bitcoin_mode',
      default: utils._getDefault( 'bitcoin_mode' ),
      message: prefix()+'Where is your bitcoin full node running?'+utils._getHelp('bitcoin_mode'),
      choices: [
        {
          name: 'Nowhere! I want cyphernode to run one.',
          value: 'internal'
        },
        {
          name: 'I have a full node running.',
          value: 'external'
        }
      ]
    },
    {
      when: bitcoinExternal,
      type: 'input',
      name: 'bitcoin_node_ip',
      default: utils._getDefault( 'bitcoin_node_ip' ),
      filter: utils._trimFilter,
      validate: utils._ipOrFQDNValidator,
      message: prefix()+'What is your full node ip address?'+utils._getHelp('bitcoin_node_ip'),
    },
    {
      type: 'input',
      name: 'bitcoin_rpcuser',
      default: utils._getDefault( 'bitcoin_rpcuser' ),
      message: prefix()+'Name of bitcoin rpc user?'+utils._getHelp('bitcoin_rpcuser'),
      filter: utils._trimFilter,
    },
    {
      type: 'password',
      name: 'bitcoin_rpcpassword',
      default: utils._getDefault( 'bitcoin_rpcpassword' ),
      message: prefix()+'Password of bitcoin rpc user?'+utils._getHelp('bitcoin_rpcpassword'),
      filter: utils._trimFilter,
    },
    {
      when: bitcoinInternal,
      type: 'confirm',
      name: 'bitcoin_prune',
      default: utils._getDefault( 'bitcoin_prune' ),
      message: prefix()+'Run bitcoin node in prune mode?'+utils._getHelp('bitcoin_prune'),
    }, // TODO: ask for size of prune
    {
      when: bitcoinInternal,
      type: 'input',
      name: 'bitcoin_uacomment',
      default: utils._getDefault( 'bitcoin_uacomment' ),
      message: prefix()+'Any UA comment?'+utils._getHelp('bitcoin_uacomment'),
      filter: utils._trimFilter,
      validate: (input)=> {return utils._optional(input,utils._UACommentValidator) }
    }];
  },
  env: function( props ) {
    return 'VAR0=VALUE0\nVAR1=VALUE1'
  },
  templates: function( props ) {
    return ['bitcoin.conf']
  }
};