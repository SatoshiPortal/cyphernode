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

const bitcoinInternalAndPrune = function(props) {
  return bitcoinInternal(props) && props.bitcoin_prune;
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
      default: utils.getDefault( 'bitcoin_mode' ),
      message: prefix()+'Cyphernode will manage your bitcoin full node.'+utils.getHelp('bitcoin_mode'),
      choices: [
        {
          name: 'Ok. That is awesome',
          value: 'internal'
        }
      ]
    },
    {
      when: bitcoinExternal,
      type: 'input',
      name: 'bitcoin_node_ip',
      default: utils.getDefault( 'bitcoin_node_ip' ),
      filter: utils.trimFilter,
      validate: utils.ipOrFQDNValidator,
      message: prefix()+'What is your full node ip address?'+utils.getHelp('bitcoin_node_ip'),
    },
    {
      type: 'input',
      name: 'bitcoin_rpcuser',
      default: utils.getDefault( 'bitcoin_rpcuser' ),
      message: prefix()+'Name of bitcoin rpc user?'+utils.getHelp('bitcoin_rpcuser'),
      filter: utils.trimFilter,
    },
    {
      type: 'password',
      name: 'bitcoin_rpcpassword',
      default: utils.getDefault( 'bitcoin_rpcpassword' ),
      message: prefix()+'Password of bitcoin rpc user?'+utils.getHelp('bitcoin_rpcpassword'),
      filter: utils.trimFilter,
    },
    {
      when: function(props) {
        return bitcoinInternal( props ) && props.features.indexOf('lightning') === -1;
      },
      type: 'confirm',
      name: 'bitcoin_prune',
      default: utils.getDefault( 'bitcoin_prune' ),
      message: prefix()+'Run bitcoin node in prune mode?'+utils.getHelp('bitcoin_prune'),
    },
    {
      when: function(props) {
        return bitcoinInternalAndPrune( props ) && props.features.indexOf('lightning') === -1;
      },
      type: 'input',
      name: 'bitcoin_prune_size',
      default: utils.getDefault( 'bitcoin_prune_size' ),
      message: prefix()+'What is the maximum size of your blockchain data in megabytes?'+utils.getHelp('bitcoin_prune_size'),
      validate: function( input ) {
        if( ! /^\d+$/.test(input) ) {
          throw new Error( "Not a number");
        }
        if( input < 550 ) {
          throw new Error( "At least 550 is required");
        }
        return true;
      }
    }, // TODO: ask for size of prune
    {
      when: bitcoinInternal,
      type: 'input',
      name: 'bitcoin_uacomment',
      default: utils.getDefault( 'bitcoin_uacomment' ),
      message: prefix()+'Any UA comment?'+utils.getHelp('bitcoin_uacomment'),
      filter: utils.trimFilter,
      validate: (input)=> {return utils.optional(input,utils.UACommentValidator) }
    }];
  },
  env: function( props ) {
    return 'VAR0=VALUE0\nVAR1=VALUE1'
  },
  templates: function( props ) {
    return ['bitcoin.conf', 'bitcoin-client.conf', 'entrypoint.sh', 'createWallets.sh', 'walletnotify.sh', 'pubNewBlock.sh'];
  }
};